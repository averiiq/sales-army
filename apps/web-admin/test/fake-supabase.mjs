// Minimal in-memory stand-in for Supabase PostgREST + GoTrue, enough to
// exercise the admin API end to end without a network or a real project.
export function createFakeSupabase() {
  const tables = {
    tenants: [], profiles: [], platform_settings: [], orders: [], order_items: [], invoices: [], shops: [],
    printer_hardware_orders: [], notifications: [], admin_audit_logs: [], subscription_checkouts: [],
    products: [], payments: [], ledger_entries: [],
  };
  const users = new Map();      // id -> { id, email, password, app_metadata, user_metadata, banned }
  const tokens = new Map();     // token -> user id
  const rpcs = {
    admin_platform_stats: () => ({}),
    admin_integrity_report: () => ({ counts: { tenants: tables.tenants.length }, ledgerDrift: [] }),
    admin_settle_checkout_manual: ({ p_id }) => {
      const c = tables.subscription_checkouts.find(x => x.id === p_id);
      if (!c) return [400, { message: 'Checkout not found' }];
      c.status = 'paid';
      return { id: p_id, status: 'paid' };
    },
  };
  const calls = [];
  let seq = 0;
  const uuid = () => `00000000-0000-4000-8000-${String(++seq).padStart(12, '0')}`;

  function parseValue(op, raw) {
    const v = decodeURIComponent(raw);
    if (op === 'in') return v.replace(/^\(|\)$/g, '').split(',').map(s => s.replace(/^"|"$/g, ''));
    return v;
  }
  function matches(row, filters) {
    return filters.every(([col, op, val]) => {
      // JSON field filter, e.g. quote->>couponCode
      const [jsonCol, jsonKey] = col.split('->>');
      const cell = jsonKey !== undefined ? row[jsonCol]?.[jsonKey] : row[col];
      if (op === 'eq') return String(cell) === val;
      if (op === 'neq') return String(cell) !== val;
      if (op === 'in') return val.includes(String(cell));
      if (op === 'is') return val === 'null' ? cell == null : String(cell) === val;
      if (op === 'gte') return cell != null && String(cell) >= val;
      return true;
    });
  }
  function parseQuery(search) {
    const filters = []; let order = null; let limit = null;
    for (const part of search.replace(/^\?/, '').split('&').filter(Boolean)) {
      const [rawKey, v = ''] = part.split(/=(.*)/s);
      const k = decodeURIComponent(rawKey);
      if (k === 'select' || k === 'on_conflict') continue;
      if (k === 'order') { order = decodeURIComponent(v).split('.')[0]; continue; }
      if (k === 'limit') { limit = Number(v); continue; }
      const [op, ...rest] = v.split('.');
      filters.push([k, op, parseValue(op, rest.join('.'))]);
    }
    return { filters, order, limit };
  }
  const res = (status, body) => new Response(body === undefined ? '' : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

  async function fetchImpl(input, init = {}) {
    const url = new URL(typeof input === 'string' ? input : input.url);
    const method = init.method || 'GET';
    const headers = new Headers(init.headers);
    const body = init.body ? JSON.parse(init.body) : undefined;
    calls.push({ method, path: url.pathname + url.search, body });
    const p = url.pathname;

    if (p === '/auth/v1/user') {
      const id = tokens.get((headers.get('Authorization') || '').replace('Bearer ', ''));
      return id ? res(200, { id, email: users.get(id).email }) : res(401, { msg: 'invalid JWT' });
    }
    if (p === '/auth/v1/token') {
      const u = [...users.values()].find(x => x.email === body.email && x.password === body.password && !x.banned);
      if (!u) return res(400, { error_description: 'Invalid login credentials' });
      const token = `tok_${u.id}`; tokens.set(token, u.id);
      return res(200, { access_token: token, refresh_token: 'r', user: { id: u.id, email: u.email } });
    }
    if (p === '/auth/v1/admin/users' && method === 'POST') {
      if ([...users.values()].some(x => x.email === body.email)) return res(422, { msg: 'A user with this email address has already been registered' });
      const id = uuid();
      users.set(id, { id, ...body });
      // handle_new_user trigger
      tables.profiles.push({ id, name: body.user_metadata?.name, email: body.email, role: body.app_metadata?.role || 'owner', tenant_id: body.app_metadata?.tenant_id || null, account_status: 'active', is_active: true });
      return res(200, { id, email: body.email });
    }
    const adminUser = p.match(/^\/auth\/v1\/admin\/users\/(.+)$/);
    if (adminUser) {
      const id = decodeURIComponent(adminUser[1]);
      if (!users.has(id)) return res(404, { msg: 'User not found' });
      if (method === 'DELETE') { users.delete(id); tables.profiles = tables.profiles.filter(x => x.id !== id); return res(200, {}); }
      const u = users.get(id);
      Object.assign(u, body, { banned: body.ban_duration ? body.ban_duration !== 'none' : u.banned });
      return res(200, { id });
    }
    const rpc = p.match(/^\/rest\/v1\/rpc\/(.+)$/);
    if (rpc) {
      const fn = rpcs[rpc[1]];
      if (!fn) return res(404, { message: `function ${rpc[1]} not found` });
      const out = fn(body || {});
      return Array.isArray(out) ? res(out[0], out[1]) : res(200, out);
    }
    const tbl = p.match(/^\/rest\/v1\/([a-z_]+)$/);
    if (!tbl || !tables[tbl[1]]) return res(404, { message: 'not found' });
    const name = tbl[1];
    const { filters, order, limit } = parseQuery(url.search);
    if (method === 'GET') {
      let rows = tables[name].filter(r => matches(r, filters));
      if (order) rows = [...rows].sort((a, b) => String(b[order] ?? '').localeCompare(String(a[order] ?? '')));
      if (limit) rows = rows.slice(0, limit);
      if (url.search.includes('couponCode:quote')) rows = rows.map(r => ({ couponCode: r.quote?.couponCode ?? null }));
      return res(200, rows);
    }
    if (method === 'POST') {
      const conflict = url.searchParams.get('on_conflict');
      const rows = (Array.isArray(body) ? body : [body]).map(r => ({ ...r }));
      const out = [];
      for (const r of rows) {
        const key = conflict ? conflict.split(',') : null;
        const existing = key ? tables[name].find(x => key.every(k => String(x[k]) === String(r[k]))) : null;
        if (existing) {
          if (!(headers.get('Prefer') || '').includes('merge-duplicates')) return res(409, { message: 'duplicate key' });
          Object.assign(existing, r); out.push(existing);
        } else {
          if (name === 'tenants' && tables.tenants.some(x => x.tenant_id === r.tenant_id)) return res(409, { message: 'duplicate key' });
          const row = { id: r.id ?? (name === 'admin_audit_logs' ? tables[name].length + 1 : uuid()), created_at: new Date().toISOString(), ...r };
          tables[name].push(row); out.push(row);
        }
      }
      return res(201, out);
    }
    if (method === 'PATCH') {
      const rows = tables[name].filter(r => matches(r, filters));
      rows.forEach(r => Object.assign(r, body));
      return res(200, rows);
    }
    if (method === 'DELETE') {
      const removed = tables[name].filter(r => matches(r, filters));
      tables[name] = tables[name].filter(r => !matches(r, filters));
      return res(200, removed);
    }
    return res(405, {});
  }

  function addUser({ email, password = 'Secret#12345', role, tenant_id = null, name = 'User', status = 'active' }) {
    const id = uuid();
    users.set(id, { id, email, password, app_metadata: { role, tenant_id } });
    tables.profiles.push({ id, name, email, role, tenant_id, account_status: status, is_active: status === 'active' });
    const token = `tok_${id}`; tokens.set(token, id);
    return { id, token };
  }

  return { fetchImpl, tables, users, rpcs, calls, addUser };
}

export const ENV = { SUPABASE_URL: 'https://fake.supabase.co', SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'service', RAZORPAY_WEBHOOK_SECRET: 'whsec_test' };
