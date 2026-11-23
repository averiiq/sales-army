/**
 * SalesArmy Admin — Cloudflare Workers entry point.
 *
 * All API logic lives in ./api/handler.mjs (shared with the Node server).
 * Required secrets (wrangler secret put …):
 *   SUPABASE_SERVICE_ROLE_KEY, RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET
 * Required vars: SUPABASE_URL, SUPABASE_ANON_KEY
 * Optional vars: ALLOWED_ORIGINS (comma separated, for cross-origin API callers)
 */
import { createApi } from './api/handler.mjs';
import { resolvePublicPath, SECURITY_HEADERS } from './api/static.mjs';

let cached = null;

function withSecurityHeaders(response) {
  const res = new Response(response.body, response);
  for (const [k, v] of Object.entries(SECURITY_HEADERS)) res.headers.set(k, v);
  return res;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname.startsWith('/api/')) {
      try {
        if (!cached || cached.env !== env) cached = { env, api: createApi(env) };
        const ip = request.headers.get('CF-Connecting-IP') || null;
        return withSecurityHeaders(await cached.api.handle(request, { ip }));
      } catch (err) {
        return withSecurityHeaders(new Response(JSON.stringify({ success: false, error: err.message || 'Server error' }), {
          status: err.status || 500, headers: { 'Content-Type': 'application/json' },
        }));
      }
    }

    if (!['GET', 'HEAD'].includes(request.method)) return new Response('Method not allowed', { status: 405 });
    const file = resolvePublicPath(url.pathname);
    if (!file || !env.ASSETS) return withSecurityHeaders(new Response('Not found', { status: 404 }));
    // Workers Assets redirects /x.html -> /x, so request HTML by clean path.
    const assetPath = file === 'index.html' ? '/' : file === 'legal.html' ? '/legal' : `/${file}`;
    const assetUrl = new URL(assetPath, url.origin);
    const res = await env.ASSETS.fetch(new Request(assetUrl, request));
    const out = withSecurityHeaders(res);
    out.headers.set('Cache-Control', file.startsWith('vendor/') ? 'public, max-age=86400' : 'no-cache');
    return out;
  },
};
