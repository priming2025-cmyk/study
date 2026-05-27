import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.46.1";
import { SignJWT } from "npm:jose@4.14.4";

type Body = {
  recipientUserId: string;
  peerId: string;
  peerDisplayName?: string;
  senderName: string;
  body: string;
};

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

async function getFcmAccessToken() {
  const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!saJson) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON");

  const sa = JSON.parse(saJson) as {
    client_email: string;
    private_key: string;
    project_id?: string;
  };

  const scope = "https://www.googleapis.com/auth/firebase.messaging";
  const now = Math.floor(Date.now() / 1000);

  const jwt = await new SignJWT({ scope })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuedAt(now)
    .setExpirationTime(now + 60 * 60)
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .sign(sa.private_key);

  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResp.ok) {
    const t = await tokenResp.text();
    throw new Error(`OAuth token failed: ${t}`);
  }

  const payload = await tokenResp.json();
  return payload.access_token as string;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: Body;
  try {
    body = await req.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Missing Supabase env" }, 500);
  }

  const fcmProjectId =
    Deno.env.get("FIREBASE_PROJECT_ID") ?? undefined;

  // 1) 토큰 가져오기
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: tokens, error } = await supabase
    .from("fcm_tokens")
    .select("token")
    .eq("user_id", body.recipientUserId);

  if (error) {
    return jsonResponse({ error: `Token query failed: ${error.message}` }, 500);
  }

  if (!tokens || tokens.length === 0) {
    return jsonResponse({ ok: true, sent: 0 });
  }

  // 2) FCM access token
  const accessToken = await getFcmAccessToken();

  // service account 내부 project_id가 있어도 되지만, env로 주입 권장
  const projectId =
    fcmProjectId ??
    (JSON.parse(
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "{}",
    )?.project_id as string | undefined);

  if (!projectId) {
    return jsonResponse({ error: "Missing FIREBASE_PROJECT_ID" }, 500);
  }

  // 3) data-only 메시지 전송 (notification 필드 미사용)
  //    방해 최소화를 위해 앱이 백그라운드/종료 상태에서 local notification을 표시할지 스스로 결정합니다.
  const sentTokens: string[] = [];

  await Promise.all(
    (tokens as { token: string }[]).map(async (t) => {
      const token = t.token;
      if (!token) return;

      const resp = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token,
              data: {
                type: "friend_dm",
                peer_id: body.peerId,
                peer_display_name: body.peerDisplayName ?? "",
                sender_name: body.senderName,
                body: body.body,
              },
            },
          }),
        },
      );

      if (resp.ok) sentTokens.push(token);
    }),
  );

  return jsonResponse({ ok: true, sent: sentTokens.length });
});

