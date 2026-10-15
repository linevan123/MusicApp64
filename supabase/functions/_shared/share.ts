import { admin } from "./supabase.ts";
import { HttpError } from "./http.ts";

export interface ShareLink {
  id: string;
  owner_id: string;
  token: string;
  project_id: string | null;
  track_id: string | null;
  label: string | null;
  allow_download: boolean;
  allow_comments: boolean;
  expires_at: string | null;
  revoked_at: string | null;
}

export interface LinkedTrack {
  id: string;
  project_id: string;
  duration: number;
}

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Loads a share link and enforces revocation + expiry. Throws HttpError otherwise. */
export async function loadActiveLink(token: unknown): Promise<ShareLink> {
  // Same 404 for malformed and unknown tokens — don't leak which is which.
  if (typeof token !== "string" || !TOKEN_PATTERN.test(token)) {
    throw new HttpError(404, "Link not found");
  }

  const { data, error } = await admin
    .from("share_links")
    .select(
      "id, owner_id, token, project_id, track_id, label, allow_download, allow_comments, expires_at, revoked_at",
    )
    .eq("token", token)
    .maybeSingle();

  if (error) throw new HttpError(500, "Lookup failed");
  if (!data) throw new HttpError(404, "Link not found");
  if (data.revoked_at) throw new HttpError(410, "This link has been revoked by its owner.");
  if (data.expires_at && new Date(data.expires_at).getTime() <= Date.now()) {
    throw new HttpError(410, "This link has expired.");
  }
  return data as ShareLink;
}

/** Ensures `trackId` is covered by the link (the track itself, or a track in the linked project). */
export async function findTrackInLink(link: ShareLink, trackId: unknown): Promise<LinkedTrack> {
  if (typeof trackId !== "string" || !UUID_PATTERN.test(trackId)) {
    throw new HttpError(404, "Track not found");
  }

  const { data, error } = await admin
    .from("tracks")
    .select("id, project_id, duration")
    .eq("id", trackId.toLowerCase())
    .maybeSingle();

  if (error) throw new HttpError(500, "Lookup failed");
  const inScope = !!data &&
    (link.track_id ? data.id === link.track_id : data.project_id === link.project_id);
  if (!inScope) throw new HttpError(404, "Track not found");

  return { id: data.id, project_id: data.project_id, duration: Number(data.duration) };
}
