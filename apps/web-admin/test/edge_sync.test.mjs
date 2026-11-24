import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { EDGE_API_FILES, SRC, DEST } from '../scripts/sync-edge.mjs';

test('Supabase edge copy of the platform API matches apps/web-admin/api (run npm.cmd run sync:edge)', () => {
  for (const f of EDGE_API_FILES) {
    assert.equal(readFileSync(join(DEST, f), 'utf8'), readFileSync(join(SRC, f), 'utf8'), `${f} is out of date`);
  }
});

test('edge wrapper routes /platform/api/* to the shared router', async () => {
  const { createApi } = await import(pathToFileURL(join(DEST, 'handler.mjs')).href);
  const api = createApi({ SUPABASE_URL: 'https://x.supabase.co', SUPABASE_ANON_KEY: 'a', SUPABASE_SERVICE_ROLE_KEY: 's' },
    { fetchImpl: async () => new Response('{}', { status: 500 }) });
  const rewrite = raw => {
    const url = new URL(raw);
    const path = url.pathname.replace(/^(\/functions\/v1)?\/platform(?=\/|$)/, '') || '/';
    url.pathname = path === '/' || path === '/health' ? '/api/health' : path;
    return url;
  };
  for (const raw of ['https://x.supabase.co/platform/api/health', 'https://x.supabase.co/functions/v1/platform/api/health', 'https://x.supabase.co/platform']) {
    const res = await api.handle(new Request(rewrite(raw)));
    assert.equal(res.status, 200, raw);
    assert.equal((await res.json()).status, 'healthy');
  }
  const unauth = await api.handle(new Request(rewrite('https://x.supabase.co/platform/api/checkout'), { method: 'POST', body: '{}' }));
  assert.equal(unauth.status, 401);
});
