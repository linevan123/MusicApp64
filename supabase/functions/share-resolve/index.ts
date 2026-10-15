// POST /functions/v1/share-resolve   { "token": "<share token>" }
//
// Public (no account needed). Validates the token and returns the shared
// project/track metadata plus short-lived signed URLs:
//   • stream_url   — always present
//   • download_url — only when the link allows downloads (Content-Disposition)
//
// Response shape is consumed by the iOS app (SharedPayload.swift) and is
// CORS-enabled so a future web player can reuse it unchanged.

import { admin } from "../_shared/supabase.ts";
import { handleError, HttpError, iso, json, preflight } from "../_shared/http.ts";
import { loadActiveLink } from "../_shared/share.ts";

const URL_TTL_SECONDS = 60 * 60 * 2; // 2h: long enough for a listening session; app re-resolves after.

const TRACK_COLUMNS =
  "id, project_id, title, audio_file_path, duration, waveform_data, format, sample_rate, bit_depth, bpm, musical_key, position, created_at";

interface TrackRow {
  id: string;
  project_id: string;
  title: string;
  audio_file_path: string;
  duration: number;
  waveform_data: number[];
  format: string | null;
  sample_rate: number | null;
  bit_depth: number | null;
  bpm: number | null;
  musical_key: string | null;
}

function downloadFilename(title: string, path: string): string {
  const ext = path.split(".").pop() ?? "wav";
  const base = title.replace(/[\\/:*?"<>|]+/g, "").trim().slice(0, 120) || "track";
  return `${base}.${ext}`;
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;

  try {
    if (req.method !== "POST") throw new HttpError(405, "Method not allowed");
    const { token } = await req.json().catch(() => ({}));
    const link = await loadActiveLink(token);

    // ---- Tracks in scope -------------------------------------------------
    let query = admin.from("tracks").select(TRACK_COLUMNS);
    query = link.track_id
      ? query.eq("id", link.track_id)
      : query.eq("project_id", link.project_id!).order("position").order("created_at");

    const { data: trackData, error: trackError } = await query;
    if (trackError) throw new HttpError(500, "Could not load tracks");
    const tracks = (trackData ?? []) as TrackRow[];
    if (link.track_id && tracks.length === 0) throw new HttpError(404, "Track not found");

    const projectId = link.project_id ?? tracks[0].project_id;

    const [{ data: project }, { data: owner }] = await Promise.all([
      admin.from("projects").select("id, title, cover_art_path").eq("id", projectId).single(),
      admin.from("profiles").select("username").eq("id", link.owner_id).single(),
    ]);
    if (!project) throw new HttpError(404, "Project not found");

    // ---- Signed URLs ------------------------------------------------------
    const audio = admin.storage.from("audio");
    const streamByPath = new Map<string, string>();
    if (tracks.length > 0) {
      const { data: signed, error } = await audio.createSignedUrls(
        tracks.map((t) => t.audio_file_path),
        URL_TTL_SECONDS,
      );
      if (error) throw new HttpError(500, "Could not sign audio URLs");
      for (const s of signed ?? []) if (s.path && s.signedUrl) streamByPath.set(s.path, s.signedUrl);
    }

    const downloadUrls: (string | null)[] = link.allow_download
      ? await Promise.all(tracks.map(async (t) => {
        const { data } = await audio.createSignedUrl(t.audio_file_path, URL_TTL_SECONDS, {
          download: downloadFilename(t.title, t.audio_file_path),
        });
        return data?.signedUrl ?? null;
      }))
      : tracks.map(() => null);

    let coverUrl: string | null = null;
    if (project.cover_art_path) {
      const { data } = await admin.storage.from("covers").createSignedUrl(
        project.cover_art_path,
        URL_TTL_SECONDS,
      );
      coverUrl = data?.signedUrl ?? null;
    }

    // Analytics; never fail the request over it.
    const { error: viewError } = await admin.rpc("record_share_view", { link_id: link.id });
    if (viewError) console.error("record_share_view", viewError);

    return json({
      kind: link.track_id ? "track" : "project",
      link: {
        id: link.id,
        label: link.label,
        allow_download: link.allow_download,
        allow_comments: link.allow_comments,
        expires_at: iso(link.expires_at),
      },
      owner: { username: owner?.username ?? "unknown" },
      project: { id: project.id, title: project.title, cover_url: coverUrl },
      // NOTE: audio_file_path is intentionally NOT exposed (it contains the owner's uid).
      tracks: tracks
        .filter((t) => streamByPath.has(t.audio_file_path))
        .map((t) => ({
          id: t.id,
          title: t.title,
          duration: Number(t.duration),
          waveform_data: t.waveform_data ?? [],
          format: t.format,
          sample_rate: t.sample_rate,
          bit_depth: t.bit_depth,
          bpm: t.bpm === null ? null : Number(t.bpm),
          musical_key: t.musical_key,
          stream_url: streamByPath.get(t.audio_file_path),
          download_url: downloadUrls[tracks.indexOf(t)],
        })),
      urls_expire_at: new Date(Date.now() + URL_TTL_SECONDS * 1000).toISOString(),
    });
  } catch (err) {
    return handleError(err);
  }
});
