-- =============================================================================
-- Bounce · Initial schema
--
-- Tables : profiles (users), projects, tracks, share_links, comments
-- Storage: private `audio` + `covers` buckets, scoped to {owner_id}/... folders
--
-- Security model
--   • Creators (authenticated) can only ever see / mutate their own rows (RLS).
--   • Guests NEVER touch tables or buckets directly. They call Edge Functions
--     (`share-resolve`, `share-comment`) which validate a share token, enforce
--     expiry / revocation / download / comment flags, and mint short-lived
--     signed URLs using the service role.
--   • Storage objects are referenced by *path*, never by a permanent public URL.
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- 144 bits of entropy, URL-safe base64 (24 chars). Unguessable share tokens.
create or replace function public.generate_share_token()
returns text
language sql
volatile
set search_path = ''
as $$
  select translate(rtrim(encode(extensions.gen_random_bytes(18), 'base64'), '='), '+/', '-_');
$$;

-- -----------------------------------------------------------------------------
-- profiles  (spec "Users": ID, Email, Username, Created_At)
-- One row per auth.users row, created automatically on sign-up.
-- -----------------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null,
  username    text not null,
  created_at  timestamptz not null default now(),
  -- Producer monikers like "prodbyevan!" are allowed.
  constraint profiles_username_format check (username ~ '^[A-Za-z0-9_.!-]{2,32}$')
);

create unique index profiles_username_lower_key on public.profiles (lower(username));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, username)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(
      nullif(new.raw_user_meta_data ->> 'username', ''),
      'user_' || substr(replace(new.id::text, '-', ''), 1, 8)
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set email = coalesce(new.email, '') where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.handle_user_email_change();

-- Lets the sign-up screen check availability without exposing the profiles table.
create or replace function public.username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select candidate ~ '^[A-Za-z0-9_.!-]{2,32}$'
     and not exists (
       select 1 from public.profiles where lower(username) = lower(candidate)
     );
$$;

revoke execute on function public.username_available(text) from public;
grant execute on function public.username_available(text) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- projects  (spec: ID, Owner_ID, Title, Cover_Art_URL)
-- `cover_art_path` stores the storage object path (covers bucket). Signed URLs
-- are minted on demand because the bucket is private.
-- -----------------------------------------------------------------------------

create table public.projects (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title           text not null check (char_length(btrim(title)) between 1 and 120),
  cover_art_path  text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index projects_owner_id_idx on public.projects (owner_id, updated_at desc);

create trigger projects_set_updated_at
  before update on public.projects
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- tracks  (spec: ID, Project_ID, Title, Audio_File_URL, Duration, Waveform_Data)
-- • `audio_file_path` = object path in the private `audio` bucket.
-- • `waveform_data`   = normalized-ish peak amplitudes (0…1), computed on-device
--                       at upload time so the scrubber renders instantly.
-- • `owner_id` is denormalized for cheap RLS + storage checks.
-- -----------------------------------------------------------------------------

create table public.tracks (
  id               uuid primary key default gen_random_uuid(),
  project_id       uuid not null references public.projects (id) on delete cascade,
  owner_id         uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title            text not null check (char_length(btrim(title)) between 1 and 200),
  audio_file_path  text not null unique,
  duration         numeric(10, 3) not null check (duration >= 0),
  waveform_data    real[] not null default '{}',
  format           text check (format in ('wav', 'flac', 'mp3', 'aiff')),
  sample_rate      integer check (sample_rate > 0),
  bit_depth        smallint check (bit_depth > 0),
  channels         smallint check (channels > 0),
  file_size_bytes  bigint check (file_size_bytes >= 0),
  bpm              numeric(6, 2) check (bpm > 0 and bpm < 1000),
  musical_key      text check (char_length(musical_key) <= 12),
  position         integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint tracks_waveform_size check (cardinality(waveform_data) <= 2048)
);

create index tracks_project_position_idx on public.tracks (project_id, position, created_at);
create index tracks_owner_id_idx on public.tracks (owner_id);

create trigger tracks_set_updated_at
  before update on public.tracks
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- share_links  — granular private links to a single track OR a whole project.
-- -----------------------------------------------------------------------------

create table public.share_links (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  token           text not null unique default public.generate_share_token(),
  project_id      uuid references public.projects (id) on delete cascade,
  track_id        uuid references public.tracks (id) on delete cascade,
  label           text check (char_length(label) <= 120),
  allow_download  boolean not null default false,   -- false = "Stream Only"
  allow_comments  boolean not null default true,
  expires_at      timestamptz,                      -- null = never expires
  revoked_at      timestamptz,
  view_count      integer not null default 0,
  last_viewed_at  timestamptz,
  created_at      timestamptz not null default now(),
  constraint share_links_single_target check (num_nonnulls(project_id, track_id) = 1)
);

create index share_links_owner_idx on public.share_links (owner_id, created_at desc);
create index share_links_project_idx on public.share_links (project_id) where project_id is not null;
create index share_links_track_idx on public.share_links (track_id) where track_id is not null;

-- Called by the share-resolve Edge Function (service role only).
create or replace function public.record_share_view(link_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.share_links
     set view_count = view_count + 1,
         last_viewed_at = now()
   where id = link_id;
$$;

revoke execute on function public.record_share_view(uuid) from public, anon, authenticated;
grant execute on function public.record_share_view(uuid) to service_role;

-- -----------------------------------------------------------------------------
-- comments  (spec: ID, Track_ID, User_ID (or Guest Name), Timestamp, Text)
-- `author_name` is a display-name snapshot filled by trigger so owners can see
-- who commented without being granted read access to other users' profiles.
-- -----------------------------------------------------------------------------

create table public.comments (
  id                 uuid primary key default gen_random_uuid(),
  track_id           uuid not null references public.tracks (id) on delete cascade,
  user_id            uuid references public.profiles (id) on delete cascade,
  guest_name         text check (guest_name is null or char_length(btrim(guest_name)) between 1 and 40),
  author_name        text not null,
  share_link_id      uuid references public.share_links (id) on delete set null,
  timestamp_seconds  numeric(10, 3) not null check (timestamp_seconds >= 0),
  body               text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at         timestamptz not null default now(),
  constraint comments_author_present check (user_id is not null or guest_name is not null)
);

create index comments_track_timestamp_idx on public.comments (track_id, timestamp_seconds);
create index comments_share_link_recent_idx on public.comments (share_link_id, created_at desc);

create or replace function public.comments_set_author_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.user_id is not null then
    select p.username into new.author_name from public.profiles p where p.id = new.user_id;
    new.guest_name := null;
  else
    new.author_name := btrim(new.guest_name);
  end if;
  return new;
end;
$$;

create trigger comments_set_author_name
  before insert on public.comments
  for each row execute function public.comments_set_author_name();

-- =============================================================================
-- Privileges (defense in depth on top of RLS)
-- =============================================================================

revoke all on public.profiles, public.projects, public.tracks, public.share_links, public.comments from anon;

revoke insert, update, delete on public.profiles from authenticated;
revoke update on public.projects, public.tracks, public.share_links, public.comments from authenticated;

-- Column-level update grants: clients can only change "editable" fields.
grant update (username)                                               on public.profiles    to authenticated;
grant update (title, cover_art_path)                                  on public.projects    to authenticated;
grant update (title, position, bpm, musical_key)                      on public.tracks      to authenticated;
grant update (label, allow_download, allow_comments, expires_at, revoked_at) on public.share_links to authenticated;
-- comments are immutable once posted (delete only).

-- =============================================================================
-- Row-Level Security
-- =============================================================================

alter table public.profiles    enable row level security;
alter table public.projects    enable row level security;
alter table public.tracks      enable row level security;
alter table public.share_links enable row level security;
alter table public.comments    enable row level security;

-- profiles ---------------------------------------------------------------------
create policy "profiles: read own"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "profiles: update own"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- projects ---------------------------------------------------------------------
create policy "projects: owner read"
  on public.projects for select to authenticated
  using (owner_id = (select auth.uid()));

create policy "projects: owner insert"
  on public.projects for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy "projects: owner update"
  on public.projects for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "projects: owner delete"
  on public.projects for delete to authenticated
  using (owner_id = (select auth.uid()));

-- tracks -----------------------------------------------------------------------
create policy "tracks: owner read"
  on public.tracks for select to authenticated
  using (owner_id = (select auth.uid()));

create policy "tracks: owner insert into own project"
  on public.tracks for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.projects p
      where p.id = tracks.project_id and p.owner_id = (select auth.uid())
    )
    -- the file must live in the owner's folder of this project
    and audio_file_path like (select auth.uid())::text || '/' || tracks.project_id::text || '/%'
  );

create policy "tracks: owner update"
  on public.tracks for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "tracks: owner delete"
  on public.tracks for delete to authenticated
  using (owner_id = (select auth.uid()));

-- share_links ------------------------------------------------------------------
create policy "share_links: owner read"
  on public.share_links for select to authenticated
  using (owner_id = (select auth.uid()));

create policy "share_links: owner insert for own content"
  on public.share_links for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and (
      (project_id is not null and exists (
        select 1 from public.projects p
        where p.id = share_links.project_id and p.owner_id = (select auth.uid())
      ))
      or
      (track_id is not null and exists (
        select 1 from public.tracks t
        where t.id = share_links.track_id and t.owner_id = (select auth.uid())
      ))
    )
  );

create policy "share_links: owner update"
  on public.share_links for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "share_links: owner delete"
  on public.share_links for delete to authenticated
  using (owner_id = (select auth.uid()));

-- comments ---------------------------------------------------------------------
-- Guests + signed-in collaborators comment through the `share-comment` Edge
-- Function. Direct inserts are only for creators commenting on their own tracks.
create policy "comments: track owner or author read"
  on public.comments for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.tracks t
      where t.id = comments.track_id and t.owner_id = (select auth.uid())
    )
  );

create policy "comments: owner comments on own tracks"
  on public.comments for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and guest_name is null
    and share_link_id is null
    and exists (
      select 1 from public.tracks t
      where t.id = comments.track_id and t.owner_id = (select auth.uid())
    )
  );

create policy "comments: author or track owner delete"
  on public.comments for delete to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.tracks t
      where t.id = comments.track_id and t.owner_id = (select auth.uid())
    )
  );

-- =============================================================================
-- Storage
--   audio/{owner_id}/{project_id}/{track_id}.{wav|flac|mp3|aiff}
--   covers/{owner_id}/{project_id}/cover-{unix}.jpg
-- Both buckets are PRIVATE. Guests only ever receive short-lived signed URLs.
-- NOTE: the effective max upload size is also capped by your project's global
-- storage limit (Dashboard → Storage → Settings). Raise it for large stems.
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'audio', 'audio', false, 1073741824,  -- 1 GiB per file
    array[
      'audio/wav', 'audio/x-wav', 'audio/wave', 'audio/vnd.wave',
      'audio/flac', 'audio/x-flac',
      'audio/mpeg', 'audio/mp3',
      'audio/aiff', 'audio/x-aiff'
    ]
  ),
  (
    'covers', 'covers', false, 10485760,  -- 10 MiB
    array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  )
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- audio ------------------------------------------------------------------------
create policy "audio: owner read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'audio'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "audio: owner upload into own project folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'audio'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.projects p
      where p.id::text = (storage.foldername(name))[2]
        and p.owner_id = (select auth.uid())
    )
  );

create policy "audio: owner update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'audio'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'audio'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "audio: owner delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'audio'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- covers -----------------------------------------------------------------------
create policy "covers: owner read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "covers: owner upload into own project folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.projects p
      where p.id::text = (storage.foldername(name))[2]
        and p.owner_id = (select auth.uid())
    )
  );

create policy "covers: owner update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "covers: owner delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
