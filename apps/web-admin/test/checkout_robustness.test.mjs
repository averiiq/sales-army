import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createCheckoutService } from '../api/checkout.mjs';

const catalog = { plans: { tiers: [{ id: 'grow', name: 'Grow', monthlyPrice: 999, yearlyPrice: 9990, isActive: true }], planGst: 18 }, coupons: [] };
const owner = { id: 'u1', role: 'owner', tenant_id: 't1' };

function harness({ linkStatus = 'created', rows = [] } = {}) {
  const calls = { links: 0, rpc: [], updates: [] };
  const db = {
    select: async (table, q) => (table === 'subscription_checkouts' ? rows.filter(r => q.includes(`id=eq.${r.id}`) || q.includes('tenant_id=eq.t1')) : []),
    rpc: async (name, args) => { calls.rpc.push(name); if (name === 'reserve_subscription_checkout') rows.unshift({ id: args.p_id, tenant_id: 't1', status: 'pending', amount: args.p_quote.amount, quote: args.p_quote, created_at: new Date().toISOString() }); return { status: 'paid' }; },
    update: async (table, filter, patch) => {
      calls.updates.push({ filter, patch });
      const row = rows.find(r => filter.includes(`id=eq.${r.id}`));
      if (row) Object.assign(row, patch.gateway_link_id ? patch : patch.status ? { status: patch.status } : {});
    },
  };
  calls.cancelled = [];
  const gateway = async (method, endpoint) => {
    if (method === 'POST' && endpoint.endsWith('/cancel')) { calls.cancelled.push(endpoint); return { status: 'cancelled' }; }
    if (method === 'POST') { calls.links += 1; return { id: `plink_${calls.links}`, short_url: `https://rzp.io/l/${calls.links}` }; }
    return { status: linkStatus };
  };
  gateway.configured = true;
  return { service: createCheckoutService({ db, gateway, getCatalog: async () => catalog }), calls, rows };
}

test('repeated Buy taps for the same plan reuse the open Razorpay link (no double payment)', async () => {
  const h = harness();
  const first = await h.service.start(owner, { planId: 'grow' });
  const second = await h.service.start(owner, { planId: 'grow' });
  assert.equal(h.calls.links, 1);
  assert.equal(second.id, first.id);
  assert.equal(second.url, first.url);
  assert.equal(second.reused, true);
});

test('a different plan or billing cycle gets its own link and the old unpaid link is cancelled', async () => {
  const h = harness();
  const first = await h.service.start(owner, { planId: 'grow' });
  const second = await h.service.start(owner, { planId: 'grow', yearly: true });
  assert.equal(h.calls.links, 2);
  assert.notEqual(second.id, first.id);
  assert.deepEqual(h.calls.cancelled, ['payment_links/plink_1/cancel']);
  assert.equal(h.rows.find(r => r.id === first.id).status, 'cancelled');
});

test('an expired open link is closed and replaced', async () => {
  const h = harness();
  const first = await h.service.start(owner, { planId: 'grow' });
  const h2 = harness({ linkStatus: 'expired', rows: h.rows });
  const next = await h2.service.start(owner, { planId: 'grow' });
  assert.notEqual(next.id, first.id);
  assert.ok(h2.calls.updates.some(u => u.patch.status === 'expired'));
});

test('new payment links are rate limited per agency', async () => {
  const now = new Date().toISOString();
  const rows = Array.from({ length: 10 }, (_, i) => ({ id: `00000000-0000-0000-0000-00000000000${i}`, tenant_id: 't1', status: 'expired', amount: 1, quote: {}, created_at: now }));
  const h = harness({ rows });
  await assert.rejects(h.service.start(owner, { planId: 'grow' }), e => e.status === 429);
});
