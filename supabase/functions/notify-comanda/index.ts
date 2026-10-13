// Envia un aviso push (Firebase Cloud Messaging) a los celulares de cocina/admin
// cuando entra una comanda nueva. Lo llama un disparador de la base de datos.
// Secretos necesarios (se guardan en Supabase, NO en el repositorio):
//   WEBHOOK_SECRET       clave compartida con el disparador de la base de datos
//   FCM_SERVICE_ACCOUNT  contenido completo del JSON de la cuenta de servicio de Firebase
import { createClient } from 'npm:@supabase/supabase-js@2';

function b64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function googleAccessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' })) + '.' + b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: unsigned + '.' + b64url(sig),
    }),
  });
  const j = await res.json();
  if (!j.access_token) throw new Error('No se pudo obtener token de Google: ' + JSON.stringify(j));
  return j.access_token as string;
}

Deno.serve(async (req) => {
  if (req.headers.get('x-webhook-secret') !== Deno.env.get('WEBHOOK_SECRET')) {
    return new Response('forbidden', { status: 403 });
  }
  const saRaw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!saRaw) return new Response('falta FCM_SERVICE_ACCOUNT', { status: 500 });
  const sa = JSON.parse(saRaw);

  const ev = await req.json().catch(() => ({}));
  const donde = ev.table ? `Mesa ${ev.table}` : (ev.takeaway ? `Para llevar: ${ev.takeaway}` : 'Para llevar');
  const title = ev.adicion ? 'Adicion a comanda' : 'Nueva comanda';
  const body = `#${ev.number ?? ''} - ${donde}`;

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: rows, error } = await admin.from('device_tokens').select('token');
  if (error) return new Response('db: ' + error.message, { status: 500 });
  if (!rows || rows.length === 0) return new Response('sin dispositivos', { status: 200 });

  const access = await googleAccessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  let enviados = 0;
  for (const { token } of rows) {
    const r = await fetch(url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          android: { priority: 'HIGH', notification: { sound: 'default' } },
        },
      }),
    });
    if (r.ok) { enviados++; continue; }
    const t = await r.text();
    // el celular ya no existe (app desinstalada): se borra su token
    if (r.status === 404 || t.includes('UNREGISTERED')) {
      await admin.from('device_tokens').delete().eq('token', token);
    }
  }
  return new Response(JSON.stringify({ enviados }), { status: 200 });
});
