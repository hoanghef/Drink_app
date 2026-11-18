'use strict';
const { HttpsError } = require('firebase-functions/v2/https');
const { createHash } = require('node:crypto');
const { buildOrder, validateRequest } = require('./order_logic');

async function placeOrder(data, auth, db, timestamp, paymentMethod = 'COD') {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  validateRequest(data);
  const ref = db.collection('orders').doc(`${auth.uid}_${data.requestId}`);
  const requestHash = createHash('sha256')
    .update(JSON.stringify({ paymentMethod, data })).digest('hex');
  const existing = await ref.get();
  if (existing.exists) {
    if (existing.data().requestHash !== requestHash)
      throw new HttpsError('already-exists', 'Request ID reused with different cart');
    return { orderId: ref.id, amount: existing.data().amount };
  }
  const amount = await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    if (snapshot.exists) {
      if (snapshot.data().requestHash !== requestHash)
        throw new HttpsError('already-exists', 'Request ID reused with different cart');
      return snapshot.data().amount;
    }
    const transactionalDb = {
      collection: name => db.collection(name),
      getAll: (...refs) => tx.getAll(...refs),
    };
    const order = await buildOrder(data, auth.uid, auth.token.email,
      transactionalDb, timestamp, paymentMethod);
    if (paymentMethod === 'VNPAY' && (!Number.isSafeInteger(order.amount * 100) ||
        order.amount * 100 > 999999999999))
      throw new HttpsError('failed-precondition', 'Amount outside VNPay limits');
    tx.create(ref, { ...order, requestHash });
    return order.amount;
  });
  return { orderId: ref.id, amount };
}
module.exports = { placeOrder };
