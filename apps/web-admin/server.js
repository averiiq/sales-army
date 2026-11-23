// SalesArmy Admin — Node.js entry point (local development, Render, Docker).
//
// Serves the admin SPA and forwards /api/* to the same stateless handler the
// Cloudflare Worker uses (api/handler.mjs). Supabase is the single source of
// truth; nothing is persisted on local disk.
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

function loadEnv() {
  for (const envPath of [path.join(__dirname, '.env'), path.join(__dirname, '..', '..', '.env')]) {
    if (!fs.existsSync(envPath)) continue;
    for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
      const match = line.match(/^\s*([\w.-]+)\s*=\s*(.*)?\s*$/);
      if (!match || line.trim().startsWith('#')) continue;
      let value = (match[2] || '').trim();
      if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
      if (process.env[match[1]] === undefined) process.env[match[1]] = value;
    }
  }
}
loadEnv();

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const TRUST_PROXY = process.env.TRUST_PROXY === 'true';
const MAX_BODY = 1024 * 1024;

const MIME = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'application/javascript; charset=utf-8',
  '.ico': 'image/x-icon', '.svg': 'image/svg+xml', '.png': 'image/png',
};

// ---- Rate limiting (per client IP, sliding minute) -------------------------
const buckets = new Map();
const LIMITS = { read: 240, write: 60, auth: 20 };
function clientIp(req) {
  const fwd = TRUST_PROXY ? String(req.headers['x-forwarded-for'] || '').split(',')[0].trim() : '';
  return fwd || req.socket.remoteAddress || 'unknown';
}
function allow(ip, kind) {
  const now = Date.now();
  const key = `${ip}|${kind}`;
  const b = buckets.get(key) || { count: 0, reset: now + 60000 };
  if (now > b.reset) { b.count = 0; b.reset = now + 60000; }
  b.count++;
  buckets.set(key, b);
  return b.count <= LIMITS[kind] ? 0 : Math.ceil((b.reset - now) / 1000);
}
setInterval(() => { const now = Date.now(); for (const [k, b] of buckets) if (now > b.reset) buckets.delete(k); }, 300000).unref();

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

async function main() {
  const { createApi } = await import('./api/handler.mjs');
  const { resolvePublicPath, SECURITY_HEADERS } = await import('./api/static.mjs');
  let api = null;
  try { api = createApi(process.env); } catch (err) { console.error('API configuration error:', err.message); }

  const send = (res, status, body, headers = {}) => {
    res.writeHead(status, { ...SECURITY_HEADERS, ...headers });
    res.end(body);
  };

  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

      if (url.pathname === '/healthz') return send(res, 200, JSON.stringify({ ok: true }), { 'Content-Type': 'application/json' });
      if (url.pathname === '/readyz') {
        const ok = Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY && process.env.SUPABASE_SERVICE_ROLE_KEY);
        return send(res, ok ? 200 : 503, JSON.stringify({ ok }), { 'Content-Type': 'application/json' });
      }

      const ip = clientIp(req);
      if (url.pathname.startsWith('/api/')) {
        const kind = url.pathname.startsWith('/api/auth/') ? 'auth' : (req.method === 'GET' ? 'read' : 'write');
        const retry = allow(ip, kind);
        if (retry) return send(res, 429, JSON.stringify({ success: false, error: `Too many requests. Retry in ${retry}s.` }), { 'Content-Type': 'application/json', 'Retry-After': String(retry) });
        if (!api) return send(res, 503, JSON.stringify({ success: false, error: 'Server configuration incomplete: set SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY.' }), { 'Content-Type': 'application/json' });

        const hasBody = !['GET', 'HEAD', 'OPTIONS'].includes(req.method);
        const body = hasBody ? await readBody(req) : undefined;
        const headers = new Headers();
        for (const [k, v] of Object.entries(req.headers)) if (v !== undefined) headers.set(k, Array.isArray(v) ? v.join(', ') : v);
        const proto = TRUST_PROXY && req.headers['x-forwarded-proto'] ? String(req.headers['x-forwarded-proto']).split(',')[0] : (req.socket.encrypted ? 'https' : 'http');
        const request = new Request(`${proto}://${req.headers.host || 'localhost'}${req.url}`, { method: req.method, headers, body });
        const response = await api.handle(request, { ip });
        const outHeaders = { ...SECURITY_HEADERS };
        response.headers.forEach((v, k) => { outHeaders[k] = v; });
        res.writeHead(response.status, outHeaders);
        res.end(Buffer.from(await response.arrayBuffer()));
        return;
      }

      if (!['GET', 'HEAD'].includes(req.method)) return send(res, 405, 'Method not allowed');
      if (allow(ip, 'read')) return send(res, 429, 'Too many requests');
      const file = resolvePublicPath(url.pathname);
      if (!file) return send(res, 404, 'Not found', { 'Content-Type': 'text/plain' });
      const filePath = path.join(__dirname, file);
      fs.readFile(filePath, (err, content) => {
        if (err) return send(res, 404, 'Not found', { 'Content-Type': 'text/plain' });
        send(res, 200, req.method === 'HEAD' ? undefined : content, {
          'Content-Type': MIME[path.extname(filePath)] || 'application/octet-stream',
          'Cache-Control': file.startsWith('vendor/') ? 'public, max-age=86400' : 'no-cache',
        });
      });
    } catch (err) {
      console.error('Request failed:', err.message);
      if (!res.headersSent) send(res, err.status || 500, JSON.stringify({ success: false, error: err.status === 413 ? 'Payload too large' : 'Internal server error' }), { 'Content-Type': 'application/json' });
      else res.end();
    }
  });

  server.listen(PORT, HOST, () => {
    if (process.send) process.send({ port: server.address().port });
    console.log(`SalesArmy admin listening on http://localhost:${server.address().port}`);
  });
  return server;
}

module.exports = main();
