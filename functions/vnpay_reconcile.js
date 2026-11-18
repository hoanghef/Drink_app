'use strict';
const { randomBytes, timingSafeEqual } = require('node:crypto');
const { isIP } = require('node:net');
const { HttpsError } = require('firebase-functions/v2/https');
const { credentialsReady, sign, vnpDate, paymentAmount } = require('./vnpay');

const endpoint = 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction';
const minimumIntervalMs = 5 * 60 * 1000;
const responseFields = ['vnp_ResponseId', 'vnp_Command', 'vnp_ResponseCode',
  'vnp_Message', 'vnp_TmnCode', 'vnp_TxnRef', 'vnp_Amount', 'vnp_BankCode',
  'vnp_PayDate', 'vnp_TransactionNo', 'vnp_TransactionType',
  'vnp_TransactionStatus', 'vnp_OrderInfo', 'vnp_PromotionCode',
  'vnp_PromotionAmount'];

function responseChecksumRaw(response) {
  return responseFields.map(key => response[key] == null ? '' : response[key]).join('|');
}
function validResponse(response, request, order, secret) {
  if (!response || typeof response !== 'object' || Array.isArray(response) ||
      responseFields.some(key => response[key] != null && typeof response[key] !== 'string') ||
      typeof response.vnp_SecureHash !== 'string' ||
      !/^[a-f0-9]{128}$/i.test(response.vnp_SecureHash)) return false;
  const expected = Buffer.from(sign(responseChecksumRaw(response), secret), 'hex');
  if (!timingSafeEqual(expected, Buffer.from(response.vnp_SecureHash, 'hex'))) return false;
  return response.vnp_Command === 'querydr' && response.vnp_TmnCode === request.vnp_TmnCode &&
    response.vnp_TxnRef === order.vnpTxnRef &&
    response.vnp_Amount === paymentAmount(order.amount) &&
    response.vnp_OrderInfo === request.vnp_OrderInfo &&
    /^\d{2}$/.test(response.vnp_ResponseCode || '') &&
    /^\d{2}$/.test(response.vnp_TransactionStatus || '');
}

async function reconcileVnpayPayment(data, auth, db, config, timestamp,
    send = fetch, now = () => Date.now(), newRequestId = () => randomBytes(16).toString('hex')) {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required');
  if (auth.token?.admin !== true) throw new HttpsError('permission-denied', 'Admin required');
  if (!data || Object.keys(data).some(key => key !== 'orderId') ||
      typeof data.orderId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(data.orderId))
    throw new HttpsError('invalid-argument', 'Invalid order ID');
  if (!credentialsReady(config) || config.queryEnabled !== true || !isIP(config.serverIp || ''))
    throw new HttpsError('failed-precondition', 'VNPay query is not configured');
  const orderRef = db.collection('orders').doc(data.orderId);
  const started = now();
  const reservation = await db.runTransaction(async tx => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found');
    const order = snap.data();
    if (order.paymentMethod !== 'VNPAY' || !/^[a-f0-9]{32}$/.test(order.vnpTxnRef || '') ||
        !/^\d{14}$/.test(order.vnpCreateDate || ''))
      throw new HttpsError('failed-precondition', 'Not a VNPay order');
    if (order.paymentStatus === 'paid') return { done: true };
    if (order.paymentStatus !== 'pending')
      throw new HttpsError('failed-precondition', 'Payment is closed');
    if (Number.isSafeInteger(order.vnpReconcileAt) &&
        started - order.vnpReconcileAt < minimumIntervalMs)
      throw new HttpsError('resource-exhausted', 'Query rate limit');
    tx.update(orderRef, { vnpReconcileAt: started });
    tx.create(orderRef.collection('audit').doc(), { action: 'vnpayReconcileRequested',
      actorUid: auth.uid, createdAt: timestamp });
    return { done: false, order };
  });
  if (reservation.done) return { paymentStatus: 'paid', alreadyRecorded: true };
  const requestId = newRequestId();
  if (!/^[a-f0-9]{32}$/.test(requestId)) throw new HttpsError('internal', 'Invalid query reference');
  const order = reservation.order;
  const request = { vnp_RequestId: requestId, vnp_Version: '2.1.0',
    vnp_Command: 'querydr', vnp_TmnCode: config.tmnCode,
    vnp_TxnRef: order.vnpTxnRef, vnp_TransactionDate: order.vnpCreateDate,
    vnp_CreateDate: vnpDate(new Date(started)), vnp_IpAddr: config.serverIp,
    vnp_OrderInfo: `Query transaction ${order.vnpTxnRef}` };
  const raw = ['vnp_RequestId', 'vnp_Version', 'vnp_Command', 'vnp_TmnCode',
    'vnp_TxnRef', 'vnp_TransactionDate', 'vnp_CreateDate', 'vnp_IpAddr',
    'vnp_OrderInfo'].map(key => request[key]).join('|');
  request.vnp_SecureHash = sign(raw, config.hashSecret);
  let response;
  try {
    const result = await send(endpoint, { method: 'POST',
      headers: { 'content-type': 'application/json' }, body: JSON.stringify(request),
      signal: AbortSignal.timeout(15000) });
    if (!result.ok) throw new Error('VNPay query failed');
    response = await result.json();
  } catch {
    throw new HttpsError('unavailable', 'VNPay query unavailable; payment remains pending');
  }
  if (!validResponse(response, request, order, config.hashSecret))
    throw new HttpsError('failed-precondition', 'Unverified VNPay query response');
  const confirmed = response.vnp_ResponseCode === '00' &&
    response.vnp_TransactionStatus === '00' && response.vnp_TransactionType === '01' &&
    /^\d{1,15}$/.test(response.vnp_TransactionNo || '') &&
    response.vnp_TransactionNo !== '0';
  const claimRef = confirmed ? db.collection('vnpayTransactions').doc(response.vnp_TransactionNo) : null;
  return db.runTransaction(async tx => {
    const fresh = await tx.get(orderRef);
    if (!fresh.exists) throw new HttpsError('not-found', 'Order not found');
    const current = fresh.data();
    if (current.paymentStatus === 'paid') return { paymentStatus: 'paid', alreadyRecorded: true };
    if (current.paymentStatus !== 'pending' || current.vnpTxnRef !== order.vnpTxnRef ||
        current.amount !== order.amount)
      throw new HttpsError('failed-precondition', 'Order changed while querying');
    const claim = claimRef ? await tx.get(claimRef) : null;
    if (claim?.exists && claim.data().orderId !== orderRef.id)
      throw new HttpsError('failed-precondition', 'Transaction belongs to another order');
    if (confirmed) {
      tx.update(orderRef, { paymentStatus: 'paid', isPaid: true, paidAt: timestamp,
        paymentUpdatedAt: timestamp, vnpTransactionNo: response.vnp_TransactionNo,
        vnpResponseCode: response.vnp_ResponseCode,
        vnpTransactionStatus: response.vnp_TransactionStatus });
      if (!claim.exists) tx.create(claimRef, { orderId: orderRef.id });
    }
    tx.create(orderRef.collection('audit').doc(), { action: 'vnpayReconcile',
      actorUid: auth.uid, resultCode: response.vnp_ResponseCode,
      transactionStatus: response.vnp_TransactionStatus,
      paid: confirmed, createdAt: timestamp });
    return { paymentStatus: confirmed ? 'paid' : 'pending', alreadyRecorded: false };
  });
}
module.exports = { reconcileVnpayPayment, responseChecksumRaw, minimumIntervalMs };
