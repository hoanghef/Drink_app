'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { updateOrderStatus, collectCodPayment, PREPARING, DELIVERING,
  COMPLETE, CANCELLED, PENDING } = require('../admin_orders');

function fixture(order) {
  const audits = [];
  const ref = { collection: () => ({ doc: () => ({}) }) };
  const db = { collection: () => ({ doc: () => ref }), runTransaction: async fn => fn({
    get: async () => ({ exists: !!order, data: () => ({ ...order }) }),
    update: (_ref, update) => Object.assign(order, update),
    create: (_ref, data) => audits.push(data),
  }) };
  return { db, order, audits };
}
const admin = { uid: 'staff', token: { admin: true } };
const user = { uid: 'user', token: {} };
const cod = () => ({ status: PENDING, paymentMethod: 'COD', paymentStatus: 'unpaid', amount: 25000 });

test('admin claim required and direct status flow audited', async () => {
  const f = fixture(cod());
  await assert.rejects(updateOrderStatus({ orderId: 'o1', status: PREPARING }, user, f.db, 'now'));
  assert.equal(f.order.status, PENDING);
  await updateOrderStatus({ orderId: 'o1', status: PREPARING }, admin, f.db, 'now');
  assert.equal(f.order.orderStatus, PREPARING);
  assert.equal(f.audits[0].actorUid, 'staff');
  await assert.rejects(updateOrderStatus({ orderId: 'o1', status: COMPLETE }, admin, f.db, 'now'));
  await updateOrderStatus({ orderId: 'o1', status: DELIVERING }, admin, f.db, 'now');
  await updateOrderStatus({ orderId: 'o1', status: COMPLETE }, admin, f.db, 'now');
  await assert.rejects(updateOrderStatus({ orderId: 'o1', status: CANCELLED }, admin, f.db, 'now'));
  assert.equal(f.audits.length, 3);
});
test('paid and VNPay pending orders cannot take unsafe transitions', async () => {
  const paid = fixture({ ...cod(), paymentStatus: 'paid' });
  await assert.rejects(updateOrderStatus({ orderId: 'o1', status: CANCELLED }, admin, paid.db, 'now'));
  const online = fixture({ ...cod(), paymentMethod: 'VNPAY', paymentStatus: 'pending' });
  await assert.rejects(updateOrderStatus({ orderId: 'o1', status: PREPARING }, admin, online.db, 'now'));
  await assert.rejects(updateOrderStatus({ orderId: 'o1', status: CANCELLED }, admin, online.db, 'now'));
  online.order.paymentStatus = 'failed';
  await updateOrderStatus({ orderId: 'o1', status: CANCELLED }, admin, online.db, 'now');
});
test('COD collection requires delivery, is idempotent and records actor', async () => {
  const f = fixture(cod());
  await assert.rejects(collectCodPayment({ orderId: 'o1' }, admin, f.db, 'now'));
  f.order.status = DELIVERING;
  await assert.rejects(collectCodPayment({ orderId: 'o1' }, user, f.db, 'now'));
  const first = await collectCodPayment({ orderId: 'o1' }, admin, f.db, 'now');
  const repeat = await collectCodPayment({ orderId: 'o1' }, admin, f.db, 'later');
  assert.equal(first.alreadyRecorded, false);
  assert.equal(repeat.alreadyRecorded, true);
  assert.equal(f.order.paidBy, 'staff');
  assert.equal(f.order.paymentStatus, 'paid');
  assert.equal(f.audits.length, 1);
  await assert.rejects(updateOrderStatus({ orderId: 'o1', status: CANCELLED }, admin, f.db, 'now'));
});
test('VNPay cannot be collected as COD; missing order rejected', async () => {
  const online = fixture({ ...cod(), status: DELIVERING, paymentMethod: 'VNPAY' });
  await assert.rejects(collectCodPayment({ orderId: 'o1' }, admin, online.db, 'now'));
  await assert.rejects(updateOrderStatus({ orderId: 'none', status: PREPARING }, admin, fixture(null).db, 'now'));
});
