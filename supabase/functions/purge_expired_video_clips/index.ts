// 만료된 study_room_video_clips — Storage 삭제 후 DB 행 제거
// Supabase Dashboard → Edge Functions → Cron: 0 * * * * (매시간)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const BUCKET = "study-snapshots";

Deno.serve(async (req) => {
  const secret = Deno.env.get("CRON_SECRET");
  if (secret) {
    const auth = req.headers.get("Authorization") ?? "";
    if (auth !== `Bearer ${secret}`) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
      });
    }
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: rows, error: listErr } = await supabase.rpc(
    "list_expired_study_room_video_clips",
    { p_limit: 500 },
  );

  if (listErr) {
    return new Response(JSON.stringify({ error: listErr.message }), {
      status: 500,
    });
  }

  const expired = (rows ?? []) as { id: string; storage_path: string }[];
  if (expired.length === 0) {
    return new Response(JSON.stringify({ deleted: 0, storage: 0 }));
  }

  const paths = expired
    .map((r) => r.storage_path?.trim())
    .filter((p) => p && p.length > 0);

  let storageRemoved = 0;
  const chunk = 50;
  for (let i = 0; i < paths.length; i += chunk) {
    const slice = paths.slice(i, i + chunk);
    const { error: rmErr } = await supabase.storage.from(BUCKET).remove(slice);
    if (!rmErr) storageRemoved += slice.length;
  }

  const ids = expired.map((r) => r.id);
  const { data: deletedCount, error: delErr } = await supabase.rpc(
    "delete_study_room_video_clip_rows",
    { p_ids: ids },
  );

  if (delErr) {
    return new Response(JSON.stringify({ error: delErr.message }), {
      status: 500,
    });
  }

  return new Response(
    JSON.stringify({
      deleted: deletedCount ?? 0,
      storage: storageRemoved,
      scanned: expired.length,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
