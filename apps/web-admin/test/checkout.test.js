const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { quoteCheckout, verifyWebhook, createCheckoutService } = require('../checkout');

const catalog = { plans: { tiers: [{ id: 'grow', name: 'Grow', monthlyPrice: 100, yearlyPrice: 1000 }], planGst: 18 },
  printerOptions: [{ id: 'p', name: 'Printer', price: 200, gstRate: 18 }], subscriptionAddons: [],
  coupons: [{ code: 'SAVE', type: 'percentage', value: 25, maxUses: 5 }] };

test('checkout prices use the published catalog and reject unavailable hardware/coupons', () => {
  const quote = quoteCheckout(catalog, { planId: 'grow', price: 1, couponCode: 'SAVE', printerId: 'p', shippingAddress: 'Warehouse Road 10' });
  assert.equal(quote.amount, 32450);
  assert.equal(quote.hardwareAmount, 23600);
  assert.throws(() => quoteCheckout(catalog, { planId: 'grow', addonIds: ['forged'] }), /unavailable/);
  assert.throws(() => quoteCheckout(catalog, { planId: 'grow', couponCode: 'forged' }), /unavailable/);
  assert.throws(() => quoteCheckout(catalog, { planId: 'grow', printerId: 'p' }), /address/);
});

test('webhooks require an exact HMAC of the raw request', () => {
  const raw = '{"event":"payment_link.paid"}';
  const signature = crypto.createHmac('sha256', 'test-secret').update(raw).digest('hex');
  assert.equal(verifyWebhook(raw, signature, 'test-secret'), true);
  assert.equal(verifyWebhook(`${raw} `, signature, 'test-secret'), false);
  assert.equal(verifyWebhook(raw, 'invalid', 'test-secret'), false);
});

test('subscription activates only for a captured payment matching stored checkout', async () => {
  const id = '00000000-0000-4000-8000-000000000001';
  let link = { id: 'plink_1', status: 'created', reference_id: id, currency: 'INR', amount: 11800, amount_paid: 11800,
    payments: [{ payment_id: 'pay_1', status: 'captured', amount: 11800 }] };
  let settlements = 0;
  const service = createCheckoutService({ getCatalog: async () => catalog, gateway: async () => link,
    database: async (method, endpoint, body) => {
      if (method === 'GET') {
        assert.match(endpoint, /tenant_id=eq.tenant-one/);
        return [{ id, status: 'pending', amount: 11800, gateway_link_id: 'plink_1' }];
      }
      if (endpoint === 'rpc/settle_subscription_checkout') { settlements++; return { status: 'paid', paymentId: body.p_payment }; }
    } });
  const user = { tenant_id: 'tenant-one' };
  assert.equal((await service.status(user, id)).status, 'created');
  assert.equal(settlements, 0);
  link = { ...link, status: 'paid', amount_paid: 1 };
  await assert.rejects(service.status(user, id), /does not match/);
  assert.equal(settlements, 0);
  link.amount_paid = 11800;
  assert.equal((await service.status(user, id)).paymentId, 'pay_1');
  assert.equal(settlements, 1);
  await assert.rejects(service.start({ role: 'sales_person', tenant_id: 'tenant-one' }, {}), /owner/);
});
