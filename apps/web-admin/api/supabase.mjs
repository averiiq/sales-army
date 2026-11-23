// Thin Supabase REST/Auth client used by the admin API. Runtime agnostic:
// works on Cloudflare Workers and Node 18+ (global fetch).

export class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export const enc = value => encodeURIComponent(String(value));

export function createDb({ url, anonKey, serviceKey, fetchImpl = fetch, timeoutMs = 15000 }) {
  if (!url || !anonKey || !serviceKey) {
    throw new HttpError(503, 'Server configuration incomplete: SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are required.');
  }
  const base = url.replace(/\/$/, '');

  async function call(method, path, body, headers = {}, key = serviceKey, bearer = key) {
    let res;
    try {
      res = await fetchImpl(base + path, {
        method,
        headers: { apikey: key, Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json', ...headers },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (err) {
      throw new HttpError(503, 'Database is unreachable. Please retry.', err.message);
    }
    const text = await res.text();
    let data = null;
    if (text) {
      try { data = JSON.parse(text); } catch (_) { data = text; }
    }
    if (!res.ok) {
      const message = (data && typeof data === 'object' && (data.message || data.msg || data.error_description || data.error)) || `Upstream request failed (${res.status})`;
      const status = res.status === 401 || res.status === 403 ? 502 : res.status >= 500 ? 502 : res.status === 409 ? 409 : 400;
      throw new HttpError(status, String(message), { upstreamStatus: res.status });
    }
    return data;
  }

  const prefer = (...parts) => ({ Prefer: parts.filter(Boolean).join(',') });

  return {
    select: (table, query = 'select=*') => call('GET', `/rest/v1/${table}?${query}`),
    insert: (table, rows, { onConflict, upsert = false, returning = true } = {}) =>
      call('POST', `/rest/v1/${table}${onConflict ? `?on_conflict=${onConflict}` : ''}`, rows,
        prefer(upsert && 'resolution=merge-duplicates', returning ? 'return=representation' : 'return=minimal')),
    update: (table, filter, patch) => call('PATCH', `/rest/v1/${table}?${filter}`, patch, prefer('return=representation')),
    remove: (table, filter) => call('DELETE', `/rest/v1/${table}?${filter}`, undefined, prefer('return=representation')),
    rpc: (fn, args = {}) => call('POST', `/rest/v1/rpc/${fn}`, args),
    authAdmin: (method, path, body) => call(method, `/auth/v1/${path}`, body),
    passwordGrant: (email, password) => call('POST', '/auth/v1/token?grant_type=password', { email, password }, {}, anonKey),
    getUser: async token => {
      try { return await call('GET', '/auth/v1/user', undefined, {}, anonKey, token); }
      catch (err) { if (err.status === 503) throw err; return null; }
    },
  };
}
