// Builds the admin panel for Vercel using the Build Output API v3:
//   .vercel/output/static/            ONLY the browser files (allow-list below)
//   .vercel/output/functions/api.func  one Node.js function running api/handler.mjs
//   .vercel/output/config.json         routes: security headers, /api/* -> function,
//                                      /legal, everything else 404
// Server source, tests, scripts, data and config files are never published.
//
// Vercel project settings: Root Directory = apps/web-admin. vercel.json sets
// the build command to `node scripts/build-vercel.mjs`.
// Local check: node scripts/build-vercel.mjs [outDir]
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PUBLIC_FILES, SECURITY_HEADERS } from '../api/static.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = process.argv[2] ? join(process.cwd(), process.argv[2]) : join(ROOT, '.vercel', 'output');
const API_MODULES = ['handler.mjs', 'catalog.mjs', 'checkout.mjs', 'supabase.mjs', 'static.mjs'];

rmSync(OUT, { recursive: true, force: true });
const STATIC = join(OUT, 'static');
const FUNC = join(OUT, 'functions', 'api.func');
mkdirSync(STATIC, { recursive: true });
mkdirSync(join(FUNC, 'api'), { recursive: true });

// 1. Static: the same allow-list the Node server and Cloudflare Worker serve.
const published = [];
for (const file of PUBLIC_FILES) {
  if (!existsSync(join(ROOT, file))) continue;
  cpSync(join(ROOT, file), join(STATIC, file));
  published.push(file);
}
mkdirSync(join(STATIC, 'vendor'), { recursive: true });
for (const f of readdirSync(join(ROOT, 'vendor')).filter(f => /^[A-Za-z0-9._-]+\.js$/.test(f))) {
  cpSync(join(ROOT, 'vendor', f), join(STATIC, 'vendor', f));
  published.push(`vendor/${f}`);
}
writeFileSync(join(STATIC, '404.html'), '<!doctype html><meta charset="utf-8"><title>Not found</title><p>Not found.</p>');

// 2. Function: adapter + the shared API modules (no bundling needed).
cpSync(join(ROOT, 'vercel', 'function.mjs'), join(FUNC, 'index.mjs'));
for (const m of API_MODULES) cpSync(join(ROOT, 'api', m), join(FUNC, 'api', m));
writeFileSync(join(FUNC, 'package.json'), JSON.stringify({ type: 'module' }));
writeFileSync(join(FUNC, '.vc-config.json'), JSON.stringify({
  runtime: 'nodejs22.x',
  handler: 'index.mjs',
  launcherType: 'Nodejs',
  shouldAddHelpers: false,
  maxDuration: 30,
  regions: ['bom1'], // Mumbai: next to the Supabase project (ap-south-1)
}, null, 2));

// 3. Routing.
writeFileSync(join(OUT, 'config.json'), JSON.stringify({
  version: 3,
  routes: [
    { src: '/(.*)', headers: SECURITY_HEADERS, continue: true },
    { src: '/vendor/(.*)', headers: { 'Cache-Control': 'public, max-age=86400' }, continue: true },
    { src: '/(index\\.html|legal\\.html|app\\.js|styles\\.css)?', headers: { 'Cache-Control': 'no-cache' }, continue: true },
    { src: '/api/(.*)', dest: '/api?__p=$1' },
    { src: '/legal/?', dest: '/legal.html' },
    { handle: 'filesystem' },
    { src: '/(.*)', status: 404, dest: '/404.html' },
  ],
}, null, 2));

console.log(`Vercel build output: ${OUT}`);
console.log(`  static (${published.length}): ${published.join(', ')}`);
console.log(`  function: api.func (${API_MODULES.join(', ')})`);
