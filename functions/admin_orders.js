'use strict';
const { HttpsError } = require('firebase-functions/v2/https');

const PENDING = 'Chờ xác nhận';
const PREPARING = 'Đang pha chế';
const DELIVERING = 'Đang giao';
const COMPLETE = 'Hoàn thành';
const CANCELLED = 'Hủy';
const transitions = {
  [PENDING]: [PREPARING, CANCELLED],
  [PREPARING]: [DELIVERING, CANCELLED],
  [DELIVERING]: [COMPLETE, CANCELLED],
  [COMPLETE]: [],
  [CANCELLED]: [],
};
function normalizeStatus(value) {
  return { processing: PENDING, completed: COMPLETE, cancelled: CANCELLED }[value] || value;
}
function adminUid(auth) {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  if (auth.token?.admin !== true) throw new HttpsError('permission-denied', 'Admin required');
  return auth.uid;
}
function orderRef(db, data) {
  if (!data || typeof data.orderId !== 'string' ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(data.orderId))
    throw new HttpsError('invalid-argument', 'Invalid order ID');
  return db.collection('orders').doc(data.orderId);
}
async function updateOrderStatus(data, auth, db, timestamp) {
  const actor = adminUid(auth);
  if (!data || Object.keys(data).some(k => !['orderId', 'status'].includes(k)) ||
      !Object.hasOwn(transitions, data.status))
    throw new HttpsError('invalid-argument', 'Invalid status');
  const ref = orderRef(db, data);
  return db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found');
    const order = snap.data();
    const previous = normalizeStatus(order.orderStatus || order.status);
    if (!Object.hasOwn(transitions, previous) || !transitions[previous].includes(data.status))
      throw new HttpsError('failed-precondition', 'Invalid status transition');
    if (order.paymentMethod !== 'COD' && order.paymentStatus !== 'paid' &&
        data.status !== CANCELLED)
      throw new HttpsError('failed-precondition', 'Online payment not confirmed');
    if (order.paymentMethod !== 'COD' && order.paymentStatus === 'pending' &&
        data.status === CANCELLED)
      throw new HttpsError('failed-precondition', 'Wait for payment result before cancellation');
    if (data.status === CANCELLED && order.paymentStatus === 'paid')
      throw new HttpsError('failed-precondition', 'Paid order cannot be cancelled');
    tx.update(ref, { orderStatus: data.status, status: data.status, updatedAt: timestamp });
    tx.create(ref.collection('audit').doc(), { action: 'orderStatus', from: previous,
      to: data.status, actorUid: actor, createdAt: timestamp });
    return { status: data.status };
  });
}
async function collectCodPayment(data, auth, db, timestamp) {
  const actor = adminUid(auth);
  if (!data || Object.keys(data).some(k => k !== 'orderId'))
    throw new HttpsError('invalid-argument', 'Invalid payload');
  const ref = orderRef(db, data);
  return db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found');
    const order = snap.data();
    const status = normalizeStatus(order.orderStatus || order.status);
    if (order.paymentMethod !== 'COD' || ![DELIVERING, COMPLETE].includes(status))
      throw new HttpsError('failed-precondition', 'COD can be collected during delivery or after completion');
    if (!Number.isSafeInteger(order.amount) || order.amount <= 0)
      throw new HttpsError('failed-precondition', 'Order amount is invalid');
    if (order.paymentStatus === 'paid') return { paymentStatus: 'paid', alreadyRecorded: true };
    if (order.paymentStatus !== 'unpaid' && order.paymentStatus != null)
      throw new HttpsError('failed-precondition', 'Invalid payment state');
    tx.update(ref, { paymentStatus: 'paid', isPaid: true, paidAt: timestamp,
      paidBy: actor, updatedAt: timestamp });
    tx.create(ref.collection('audit').doc(), { action: 'collectCOD', actorUid: actor,
      amount: order.amount, createdAt: timestamp });
    return { paymentStatus: 'paid', alreadyRecorded: false };
  });
}
module.exports = { updateOrderStatus, collectCodPayment, normalizeStatus,
  PENDING, PREPARING, DELIVERING, COMPLETE, CANCELLED };
