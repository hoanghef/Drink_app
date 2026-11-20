'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { placeOrder } = require('../place_order');

function mockDb({ legacyCategory = false } = {}) {
  const orders = new Map();
  const getAll = async (...refs) => refs.map(ref => ({ id: ref.id, exists: true,
    ...(ref.name === 'categories' && legacyCategory ? { exists: false } : {}),
    data: () => ref.name === 'categories'
      ? { name: 'traditional', isActive: true }
      : { name: 'Coffee', price: 25000, category: 'traditional', isAvailable: true } }));
  const db = {
    collection: name => ({
      doc: id => ({ name, id, get: async () => ({
        exists: orders.has(id), data: () => orders.get(id),
      }) }),
      where: (field, op, key) => ({
        limit: count => ({ name, field, op, key, count }),
      }),
    }),
    getAll,
    runTransaction: async fn => fn({
      get: async ref => ref.field === 'name'
        ? { docs: legacyCategory ? [{ id: 'ca-phe-truyen-thong', exists: true,
          data: () => ({ name: ref.key, isActive: true }) }] : [] }
        : { exists: orders.has(ref.id), data: () => orders.get(ref.id) },
      getAll,
      create: (ref, value) => orders.set(ref.id, value),
    }),
  };
  return { db, orders };
}
const payload = { requestId: '0123456789abcdef0123456789abcdef',
  expectedAmount: 30000, items: [{ productId: 'p1', size: 'M', quantity: 1 }],
  isDelivery: false, deliveryAddress: null };
const auth = { uid: 'u1', token: { email: 'u@example.com' } };

test('retry returns the same order and never creates a second', async () => {
  const { db, orders } = mockDb();
  const first = await placeOrder(payload, auth, db, 'now');
  const retry = await placeOrder(payload, auth, db, 'later');
  assert.deepEqual(retry, first);
  assert.equal(orders.size, 1);
  assert.equal(orders.values().next().value.items[0].price, 30000);
  await assert.rejects(placeOrder({ ...payload, expectedAmount: 1 }, auth, db, 'later'));
  assert.equal(orders.size, 1);
});

test('existing legacy category is checked inside transaction without duplicate orders', async () => {
  const { db, orders } = mockDb({ legacyCategory: true });
  const first = await placeOrder(payload, auth, db, 'now');
  const retry = await placeOrder(payload, auth, db, 'later');
  assert.deepEqual(retry, first);
  assert.equal(orders.size, 1);
});
test('invalid checkout creates no order', async () => {
  const { db, orders } = mockDb();
  await assert.rejects(placeOrder({ ...payload, items: [{ ...payload.items[0], quantity: 0 }] }, auth, db, 'now'));
  await assert.rejects(placeOrder(payload, null, db, 'now'));
  assert.equal(orders.size, 0);
});
test('catalog is read inside the order creation transaction', async () => {
  const { db, orders } = mockDb();
  db.getAll = async () => { throw new Error('Non-transactional catalog read'); };
  await placeOrder(payload, auth, db, 'now');
  assert.equal(orders.size, 1);
});
