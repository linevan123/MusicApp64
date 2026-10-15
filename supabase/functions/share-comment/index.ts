// Timestamped waveform comments for people holding a share link.
//
//   GET  /functions/v1/share-comment?token=<t>&track_id=<uuid>
//        → [Comment]
//   POST /functions/v1/share-comment
//        { token, track_id, timestamp_seconds, body, guest_name? }
//        → Comment
//
// Signed-in users are attributed to their profile automatically; guests must
// provide a display name. No account required.

import { admin, optionalUserId } from "../_shared/supabase.ts";
import { handleError, HttpError, iso, json, preflight } from "../_shared/http.ts";
import { findTrackInLink, loadActiveLink } from "../_shared/share.ts";

const COMMENT_COLUMNS = "id, track_id, user_id, author_name, timestamp_seconds, body, created_at";
const MAX_COMMENTS_PER_LINK_PER_MINUTE = 30;

interface CommentRow {
  id: string;
  track_id: string;
  user_id: string | null;
  author_name: string;
  timestamp_seconds: number;
  body: string;
  created_at: string;
}

const serialize = (c: CommentRow) => ({
  ...c,
  timestamp_seconds: Number(c.timestamp_seconds),
  created_at: iso(c.created_at),
});

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;

  try {
    if (req.method === "GET") {
      const url = new URL(req.url);
      const link = await loadActiveLink(url.searchParams.get("token"));
      const track = await findTrackInLink(link, url.searchParams.get("track_id"));

      const { data, error } = await admin
        .from("comments")
        .select(COMMENT_COLUMNS)
        .eq("track_id", track.id)
        .order("timestamp_seconds")
        .order("created_at");
      if (error) throw new HttpError(500, "Could not load comments");
      return json((data as CommentRow[]).map(serialize));
    }

    if (req.method === "POST") {
      const input = await req.json().catch(() => ({}));
      const link = await loadActiveLink(input.token);
      if (!link.allow_comments) throw new HttpError(403, "Comments are turned off for this link.");
      const track = await findTrackInLink(link, input.track_id);

      const body = String(input.body ?? "").trim();
      if (body.length < 1 || body.length > 1000) {
        throw new HttpError(400, "Comment must be 1–1000 characters.");
      }

      const rawTs = Number(input.timestamp_seconds);
      if (!Number.isFinite(rawTs) || rawTs < 0) throw new HttpError(400, "Invalid timestamp.");
      const timestamp = Math.min(rawTs, track.duration);

      const userId = await optionalUserId(req);
      let guestName: string | null = null;
      if (!userId) {
        guestName = String(input.guest_name ?? "").trim();
        if (guestName.length < 1 || guestName.length > 40) {
          throw new HttpError(400, "Add your name (1–40 characters) to comment.");
        }
      }

      // Basic abuse protection per link.
      const since = new Date(Date.now() - 60_000).toISOString();
      const { count } = await admin
        .from("comments")
        .select("id", { count: "exact", head: true })
        .eq("share_link_id", link.id)
        .gte("created_at", since);
      if ((count ?? 0) >= MAX_COMMENTS_PER_LINK_PER_MINUTE) {
        throw new HttpError(429, "Too many comments — slow down a little.");
      }

      const { data, error } = await admin
        .from("comments")
        .insert({
          track_id: track.id,
          user_id: userId,
          guest_name: guestName,
          share_link_id: link.id,
          timestamp_seconds: timestamp,
          body,
        })
        .select(COMMENT_COLUMNS)
        .single();
      if (error) throw new HttpError(500, "Could not post comment");
      return json(serialize(data as CommentRow), 201);
    }

    throw new HttpError(405, "Method not allowed");
  } catch (err) {
    return handleError(err);
  }
});
