// SalesArmy platform API on Supabase Edge Functions.
//
// Runs the exact same code as the web-admin Node server / Cloudflare Worker
// (apps/web-admin/api, copied by `npm.cmd run sync:edge`): Razorpay checkout,
// signup, staff provisioning, backups, password resets, admin endpoints.
//
// URL:  https://<project>.supabase.co/functions/v1/platform/api/...
// Deploy with --no-verify-jwt: the API checks the user's token itself, and
// the Razorpay webhook / signup calls carry no Supabase JWT.
//
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY are
// provided by Supabase automatically. Set the rest with:
//   npx supabase secrets set RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=...
import { createApi } from '../_shared/platform-api/handler.mjs';

const ENV_KEYS = [
  'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY',
  'RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET', 'RAZORPAY_WEBHOOK_SECRET', 'ALLOWED_ORIGINS',
];
const env: Record<string, string> = {};
for (const k of ENV_KEYS) env[k] = Deno.env.get(k) ?? '';

const api = createApi(env);
const SECURITY_HEADERS: Record<string, string> = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Cache-Control': 'no-store',
};

Deno.serve(async (request: Request) => {
  // Supabase passes /platform/api/... (or /functions/v1/platform/api/...);
  // the shared router expects /api/....
  const url = new URL(request.url);
  const path = url.pathname.replace(/^(\/functions\/v1)?\/platform(?=\/|$)/, '') || '/';
  if (path === '/' || path === '/health') url.pathname = '/api/health';
  else url.pathname = path;

  const rewritten = new Request(url.toString(), request);
  const ip = (request.headers.get('x-forwarded-for') || '').split(',')[0].trim() || null;
  try {
    const res = await api.handle(rewritten, { ip });
    const out = new Response(res.body, res);
    for (const [k, v] of Object.entries(SECURITY_HEADERS)) out.headers.set(k, v);
    return out;
  } catch (err) {
    const e = err as { status?: number; message?: string };
    return new Response(JSON.stringify({ success: false, error: e.message || 'Server error' }), {
      status: e.status || 500,
      headers: { 'Content-Type': 'application/json', ...SECURITY_HEADERS },
    });
  }
});
