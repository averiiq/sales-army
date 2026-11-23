// Only these files are ever served to browsers. Everything else in the
// project directory (data/, api/, tests, configs, .env, scripts) is refused,
// regardless of how the deployment uploads assets.
export const PUBLIC_FILES = new Set(['index.html', 'legal.html', 'app.js', 'styles.css', 'favicon.ico']);

export function resolvePublicPath(pathname) {
  let p = decodeURIComponent(pathname || '/');
  if (p === '/' || p === '') return 'index.html';
  if (p === '/legal' || p === '/legal/') return 'legal.html';
  p = p.replace(/^\/+/, '');
  if (p.includes('..') || p.includes('\\') || p.split('/').some(seg => seg.startsWith('.'))) return null;
  if (PUBLIC_FILES.has(p)) return p;
  if (/^vendor\/[A-Za-z0-9._-]+\.js$/.test(p)) return p;
  return null;
}

export const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'same-origin',
  'X-Frame-Options': 'DENY',
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains',
  'Permissions-Policy': 'geolocation=(), microphone=(), camera=(), payment=()',
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Content-Security-Policy': [
    "default-src 'self'",
    // index.html still uses inline onclick handlers; all interpolated data is
    // HTML-escaped by the app. Remove 'unsafe-inline' once handlers move to
    // addEventListener.
    "script-src 'self' 'unsafe-inline'",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' https://fonts.gstatic.com data:",
    "img-src 'self' data: blob: https:",
    "connect-src 'self' https://*.supabase.co wss://*.supabase.co",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "object-src 'none'",
  ].join('; '),
};
