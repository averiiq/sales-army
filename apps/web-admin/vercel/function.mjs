// Vercel Node.js function: runs the SAME platform API as the Node server,
// the Cloudflare Worker and the Supabase Edge Function (api/handler.mjs).
// Packaged into .vercel/output/functions/api.func by scripts/build-vercel.mjs.
//
// Environment (Vercel → Project → Settings → Environment Variables):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY (sensitive),
//   RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET (optional)
import { createApi } from './api/handler.mjs';
import { SECURITY_HEADERS } from './api/static.mjs';

const MAX_BODY = 1024 * 1024;
let api = null;
let configError = null;
try { api = createApi(process.env); } catch (err) { configError = err.message; }

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', chunk => {
      size += chunk.length;
      if (size > MAX_BODY) { reject(Object.assign(new Error('Payload too large'), { status: 413 })); req.destroy(); return; }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

/**
 * The route sends /api/<rest> here as "/api?__p=<rest>". Depending on the
 * platform, req.url is either the original path (/api/auth/login?...) or the
 * rewritten one (/api?__p=auth/login&...). Rebuild the original either way.
 */
export function originalUrl(rawUrl, host = 'localhost', proto = 'https') {
  const url = new URL(rawUrl || '/', `${proto}://${host}`);
  const rest = url.searchParams.get('__p');
  url.searchParams.delete('__p');
  if (!url.pathname.startsWith('/api/') && rest !== null) {
    url.pathname = `/api/${rest.replace(/^\/+/, '')}`;
  }
  return url;
}

export default async function handler(req, res) {
  const send = (status, body, headers = {}) => {
    res.statusCode = status;
    for (const [k, v] of Object.entries({ ...SECURITY_HEADERS, ...headers })) res.setHeader(k, v);
    res.end(body);
  };
  try {
    if (!api) {
      return send(503, JSON.stringify({ success: false, error: `Server configuration incomplete: ${configError}` }), { 'Content-Type': 'application/json' });
    }
    const proto = String(req.headers['x-forwarded-proto'] || 'https').split(',')[0];
    const url = originalUrl(req.url, req.headers.host, proto);
    const hasBody = !['GET', 'HEAD', 'OPTIONS'].includes(req.method);
    const body = hasBody ? await readBody(req) : undefined;
    const headers = new Headers();
    for (const [k, v] of Object.entries(req.headers)) if (v !== undefined) headers.set(k, Array.isArray(v) ? v.join(', ') : v);
    const ip = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim() || null;
    const response = await api.handle(new Request(url, { method: req.method, headers, body }), { ip });
    res.statusCode = response.status;
    for (const [k, v] of Object.entries(SECURITY_HEADERS)) res.setHeader(k, v);
    response.headers.forEach((v, k) => res.setHeader(k, v));
    res.end(Buffer.from(await response.arrayBuffer()));
  } catch (err) {
    console.error('[vercel api] request failed:', err?.message);
    if (!res.headersSent) send(err?.status || 500, JSON.stringify({ success: false, error: err?.status === 413 ? 'Payload too large' : 'Internal server error' }), { 'Content-Type': 'application/json' });
    else res.end();
  }
}
