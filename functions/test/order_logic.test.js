'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { buildOrder } = require('../order_logic');

const db = {
  collection: name => ({ doc: id => ({ name, id }) }),
  getAll: async (...refs) => refs.map(ref => ({ id: ref.id,
    exists: ref.name === 'categories' ? ref.id === 'traditional' : ref.id === 'p1',
    data: () => ref.name === 'categories'
      ? { name: 'traditional', isActive: true }
      : { name: 'Coffee', price: 25000, category: 'traditional', isAvailable: true } })),
};
const valid = { items: [{ productId: 'p1', size: 'M', quantity: 2 }], expectedAmount: 60000,
  requestId: '0123456789abcdef0123456789abcdef',
  isDelivery: true, deliveryAddress: { city: 'Ha Noi', detailedAddress: '12 Main St' } };

test('server computes price, owner and unpaid status', async () => {
  const order = await buildOrder(valid, 'u1', 'u@example.com', db, 'server-time');
  assert.equal(order.amount, 60000);
  assert.equal(order.userId, 'u1');
  assert.equal(order.isPaid, false);
  assert.equal(order.paymentMethod, 'COD');
  assert.equal(order.items[0].price, 30000);
});
test('forged payment, price and owner fields are rejected', async () => {
  for (const field of [{ isPaid: true }, { amount: 1 }, { userId: 'other' },
    { items: [{ ...valid.items[0], price: 1 }] }]) {
    await assert.rejects(buildOrder({ ...valid, ...field }, 'u1', '', db, null));
  }
});
test('invalid quantity and unavailable product are rejected', async () => {
  await assert.rejects(buildOrder({ ...valid, items: [{ productId: 'p1', size: 'M', quantity: -1 }] }, 'u1', '', db, null));
  await assert.rejects(buildOrder({ ...valid, items: [{ productId: 'missing', size: 'M', quantity: 1 }] }, 'u1', '', db, null));
});
test('outdated client total cannot silently create an order', async () => {
  await assert.rejects(buildOrder({ ...valid, expectedAmount: 1 }, 'u1', '', db, null));
});
test('checkout rejects missing, inactive and mismatched category', async () => {
  for (const category of [null, { name: 'traditional', isActive: false },
    { name: 'other', isActive: true }]) {
    const customDb = {
      ...db,
      getAll: async (...refs) => refs.map(ref => ref.name === 'categories'
        ? { id: ref.id, exists: category !== null, data: () => category }
        : { id: ref.id, exists: true, data: () => ({ name: 'Coffee', price: 25000,
          category: 'traditional', isAvailable: true }) }),
    };
    await assert.rejects(buildOrder(valid, 'u1', '', customDb, null),
      { code: 'failed-precondition' });
  }
});
