// Vercel deployment (Build Output API): only browser files are published, the
// routing config is sane, and the built function answers /api/* in both URL
// styles Vercel may pass (original path, or rewritten "/api?__p=...").
// The live part reads keys from apps/web-admin/.env and only makes
// read-only calls; it is skipped when the keys are absent.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = mkdtempSync(join(tmpdir(), 'sa-vercel-'));
execFileSync(process.execPath, [join(ROOT, 'scripts', 'build-vercel.mjs'), relative(process.cwd(), OUT)], { stdio: 'pipe' });

const walk = dir => readdirSync(dir).flatMap(f => (statSync(join(dir, f)).isDirectory() ? walk(join(dir, f)) : [join(dir, f)]));
const staticFiles = walk(join(OUT, 'static')).map(f => relative(join(OUT, 'static'), f).replace(/\\/g, '/')).sort();

test('only browser files are published as static assets', () => {
  for (const must of ['index.html', 'legal.html', 'app.js', 'styles.css', 'vendor/jspdf.umd.min.js', 'vendor/xlsx.full.min.js', '404.html']) {
    assert.ok(staticFiles.includes(must), `missing ${must}`);
  }
  for (const f of staticFiles) {
    assert.ok(/^(index\.html|legal\.html|app\.js|styles\.css|favicon\.ico|404\.html|vendor\/[A-Za-z0-9._-]+\.js)$/.test(f), `unexpected public file: ${f}`);
  }
});

test('routing: security headers everywhere, /api to the function, unknown paths 404', () => {
  const cfg = JSON.parse(readFileSync(join(OUT, 'config.json'), 'utf8'));
  assert.equal(cfg.version, 3);
  const routes = cfg.routes;
  assert.equal(routes[0].src, '/(.*)');
  assert.equal(routes[0].headers['X-Frame-Options'], 'DENY');
  assert.equal(routes[0].continue, true);
  const api = routes.findIndex(r => r.src === '/api/(.*)');
  const fs = routes.findIndex(r => r.handle === 'filesystem');
  assert.ok(api > 0 && api < fs, '/api route must come before the filesystem phase');
  assert.equal(routes.at(-1).status, 404);
  const vc = JSON.parse(readFileSync(join(OUT, 'functions', 'api.func', '.vc-config.json'), 'utf8'));
  assert.equal(vc.launcherType, 'Nodejs');
  assert.equal(vc.handler, 'index.mjs');
  assert.ok(existsSync(join(OUT, 'functions', 'api.func', 'api', 'handler.mjs')));
});

function envFromFile() {
  const file = join(ROOT, '.env');
  const out = {};
  if (!existsSync(file)) return out;
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !line.trim().startsWith('#')) out[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return out;
}
const env = envFromFile();
const live = Boolean(env.SUPABASE_URL && env.SUPABASE_ANON_KEY && env.SUPABASE_SERVICE_ROLE_KEY);

test('built function serves /api in both URL styles (live, read-only)', { skip: !live && 'no Supabase keys in .env' }, async () => {
  for (const k of ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY']) process.env[k] = env[k];
  const mod = await import(pathToFileURL(join(OUT, 'functions', 'api.func', 'index.mjs')).href);
  const server = createServer((req, res) => mod.default(req, res));
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    // Original path (rewrite keeps req.url)
    const h1 = await fetch(`${base}/api/platform/health`);
    assert.equal(h1.status, 200);
    assert.equal((await h1.json()).database, 'reachable');
    assert.equal(h1.headers.get('x-frame-options'), 'DENY');
    // Rewritten path (req.url = destination with __p)
    const h2 = await fetch(`${base}/api?__p=platform/health`);
    assert.equal(h2.status, 200);
    // Query strings survive the rewrite: export requires ?entity=..., admin-only -> 401 not 404
    const q = await fetch(`${base}/api?__p=platform/audit-logs&category=ALL`);
    assert.equal(q.status, 401);
    // Admin data needs a Super Admin token
    assert.equal((await fetch(`${base}/api/platform/all`)).status, 401);
    // POST body reaches the API (wrong password -> normal 401)
    const login = await fetch(`${base}/api/auth/login`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'nobody@example.com', password: 'not-a-real-password' }),
    });
    assert.equal(login.status, 401);
    assert.equal((await login.json()).error, 'Invalid email or password.');
    const cfg = await (await fetch(`${base}/api/config/supabase`)).json();
    assert.equal(cfg.supabaseUrl, env.SUPABASE_URL);
  } finally {
    server.close();
  }
});

test.after(() => rmSync(OUT, { recursive: true, force: true }));
