// Copies the platform API (apps/web-admin/api) into the Supabase Edge
// Function bundle so the SAME code runs on Node, Cloudflare and Supabase.
// Run after changing anything in api/:   npm.cmd run sync:edge
import { copyFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const EDGE_API_FILES = ['catalog.mjs', 'checkout.mjs', 'handler.mjs', 'supabase.mjs'];
const here = dirname(fileURLToPath(import.meta.url));
export const SRC = join(here, '..', 'api');
export const DEST = join(here, '..', '..', '..', 'supabase', 'functions', '_shared', 'platform-api');

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  mkdirSync(DEST, { recursive: true });
  for (const f of EDGE_API_FILES) copyFileSync(join(SRC, f), join(DEST, f));
  console.log(`Synced ${EDGE_API_FILES.length} API files -> ${DEST}`);
}
