'use strict';
const { createHmac, randomBytes, timingSafeEqual } = require('node:crypto');
const { isIP } = require('node:net');
const { HttpsError } = require('firebase-functions/v2/https');
const { placeOrder } = require('./place_order');

const payEndpoint = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
const version = '2.1.0';

function validHttpsUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.hostname.endsWith('.invalid') &&
      value.length <= 255 && !url.username && !url.password;
  } catch { return false; }
}
function credentialsReady(config) {
  return /^[A-Za-z0-9]{8}$/.test(config?.tmnCode || '') &&
    typeof config?.hashSecret === 'string' && config.hashSecret.length > 0;
}
function configured(config) {
  return config?.enabled === true && credentialsReady(config) &&
    validHttpsUrl(config.returnUrl) && validHttpsUrl(config.ipnUrl) &&
    /^[a-zA-Z]{1,100}$/.test(config.orderType || 'other');
}
function encoded(params) {
  const entries = Object.entries(params).filter(([key, value]) =>
    key.startsWith('vnp_') && key !== 'vnp_SecureHash' &&
    key !== 'vnp_SecureHashType' && value != null && value !== '');
  if (entries.some(([, value]) => typeof value !== 'string'))
    throw new Error('Invalid VNPay parameter');
  entries.sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0);
  return new URLSearchParams(entries).toString();
}
function sign(value, secret) {
  return createHmac('sha512', secret).update(value, 'utf8').digest('hex');
}
function checksumMatches(params, secret) {
  const given = params?.vnp_SecureHash;
  if (typeof given !== 'string' || !/^[a-f0-9]{128}$/i.test(given)) return false;
  try {
    const actual = Buffer.from(sign(encoded(params), secret), 'hex');
    return timingSafeEqual(actual, Buffer.from(given, 'hex'));
  } catch { return false; }
}
function vnpDate(date) {
  const local = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  const pad = value => String(value).padStart(2, '0');
  return `${local.getUTCFullYear()}${pad(local.getUTCMonth() + 1)}` +
    `${pad(local.getUTCDate())}${pad(local.getUTCHours())}` +
    `${pad(local.getUTCMinutes())}${pad(local.getUTCSeconds())}`;
}
function paymentAmount(amount) {
  if (!Number.isSafeInteger(amount) || amount <= 0 ||
      !Number.isSafeInteger(amount * 100) || amount * 100 > 999999999999)
    throw new HttpsError('failed-precondition', 'VNPay amount out of range');
  return String(amount * 100);
}
function customerIp(value) {
  const ip = typeof value === 'string' ? value.replace(/^::ffff:/, '') : '';
  if (!isIP(ip) || ip.length > 45) throw new HttpsError('invalid-argument', 'Invalid IP address');
  return ip;
}
function paymentUrl(order, config) {
  const params = {
    vnp_Version: version, vnp_Command: 'pay', vnp_TmnCode: config.tmnCode,
    vnp_Amount: paymentAmount(order.amount), vnp_CurrCode: 'VND',
    vnp_TxnRef: order.vnpTxnRef, vnp_OrderInfo: order.vnpOrderInfo,
    vnp_OrderType: config.orderType || 'other', vnp_ReturnUrl: config.returnUrl,
    vnp_IpAddr: order.vnpIpAddr, vnp_Locale: 'vn',
    vnp_CreateDate: order.vnpCreateDate, vnp_ExpireDate: order.vnpExpireDate,
  };
  const query = encoded(params);
  return `${payEndpoint}?${query}&vnp_SecureHash=${sign(query, config.hashSecret)}`;
}

async function createVnpayPayment(data, auth, db, timestamp, config, ip,
    now = new Date(), newRef = () => randomBytes(16).toString('hex')) {
  if (!configured(config)) throw new HttpsError('failed-precondition', 'VNPay Sandbox is not configured');
  const safeIp = customerIp(ip);
  const { orderId } = await placeOrder(data, auth, db, timestamp, 'VNPAY');
  const ref = db.collection('orders').doc(orderId);
  const transactionRef = newRef();
  if (!/^[a-f0-9]{32}$/.test(transactionRef))
    throw new HttpsError('internal', 'Invalid payment reference');
  const reserved = await db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.data().paymentMethod !== 'VNPAY')
      throw new HttpsError('failed-precondition', 'Invalid order');
    const order = snap.data();
    if (order.paymentStatus !== 'pending')
      throw new HttpsError('failed-precondition', 'Payment is closed');
    if (order.vnpTxnRef) return order;
    const created = vnpDate(now);
    const expires = vnpDate(new Date(now.getTime() + 15 * 60 * 1000));
    const fields = { vnpTxnRef: transactionRef, vnpCreateDate: created,
      vnpExpireDate: expires, vnpIpAddr: safeIp,
      vnpOrderInfo: `Drink order ${transactionRef}` };
    tx.create(db.collection('vnpayRefs').doc(transactionRef), { orderId });
    tx.update(ref, fields);
    return { ...order, ...fields };
  });
  if (reserved.vnpExpireDate < vnpDate(now))
    throw new HttpsError('failed-precondition', 'Payment URL expired; order remains pending');
  return { orderId, payUrl: paymentUrl(reserved, config), paymentStatus: 'pending' };
}

function ipnResponse(RspCode, Message) { return { RspCode, Message }; }
async function processVnpayIpn(params, db, config, timestamp) {
  // Disabling new payments must not prevent settlement of existing pending orders.
  if (!credentialsReady(config) || !checksumMatches(params, config.hashSecret))
    return ipnResponse('97', 'Invalid checksum');
  const txnRef = params.vnp_TxnRef;
  const transactionNo = params.vnp_TransactionNo;
  if (!/^[a-f0-9]{32}$/.test(txnRef || '') ||
      !/^\d{1,12}$/.test(params.vnp_Amount || '') ||
      !/^\d{2}$/.test(params.vnp_ResponseCode || '') ||
      !/^\d{2}$/.test(params.vnp_TransactionStatus || '') ||
      (transactionNo != null && !/^\d{1,15}$/.test(transactionNo)))
    return ipnResponse('99', 'Invalid payment data');
  const mappingRef = db.collection('vnpayRefs').doc(txnRef);
  return db.runTransaction(async tx => {
    const mapping = await tx.get(mappingRef);
    if (!mapping.exists) return ipnResponse('01', 'Order not found');
    const orderRef = db.collection('orders').doc(mapping.data().orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) return ipnResponse('01', 'Order not found');
    const order = orderSnap.data();
    if (order.paymentMethod !== 'VNPAY' || order.vnpTxnRef !== txnRef ||
        params.vnp_TmnCode !== config.tmnCode ||
        params.vnp_OrderInfo !== order.vnpOrderInfo)
      return ipnResponse('99', 'Order does not match');
    if (params.vnp_Amount !== paymentAmount(order.amount))
      return ipnResponse('04', 'Invalid amount');
    if (order.paymentStatus !== 'pending')
      return ipnResponse('02', 'Order already confirmed');
    const success = params.vnp_ResponseCode === '00' &&
      params.vnp_TransactionStatus === '00';
    if (success && (!transactionNo || transactionNo === '0'))
      return ipnResponse('99', 'Invalid transaction number');
    const claimRef = success ? db.collection('vnpayTransactions').doc(transactionNo) : null;
    const claim = claimRef ? await tx.get(claimRef) : null;
    if (claim?.exists && claim.data().orderId !== orderRef.id)
      return ipnResponse('99', 'Transaction already belongs to another order');
    const next = success ? 'paid' :
      params.vnp_ResponseCode === '24' && params.vnp_TransactionStatus !== '00' ? 'canceled' :
      params.vnp_TransactionStatus === '02' ? 'failed' : 'pending';
    if (next === 'pending') return ipnResponse('99', 'Result remains pending');
    tx.update(orderRef, { paymentStatus: next, isPaid: success,
      vnpTransactionNo: transactionNo || null,
      vnpResponseCode: params.vnp_ResponseCode,
      vnpTransactionStatus: params.vnp_TransactionStatus,
      paymentUpdatedAt: timestamp, ...(success ? { paidAt: timestamp } : {}) });
    if (claimRef && !claim.exists) tx.create(claimRef, { orderId: orderRef.id });
    tx.create(orderRef.collection('audit').doc(), { action: 'vnpayIpn',
      from: 'pending', to: next, txnRef, transactionNo: transactionNo || null,
      createdAt: timestamp });
    return ipnResponse('00', 'Confirm Success');
  });
}

function returnPage() {
  return '<!doctype html><html lang="vi"><meta charset="utf-8"><title>Drink App</title>' +
    '<body><p>Hãy quay lại ứng dụng để xem trạng thái thanh toán.</p></body></html>';
}
module.exports = { credentialsReady, configured, encoded, sign, checksumMatches, vnpDate,
  paymentAmount, paymentUrl, createVnpayPayment, processVnpayIpn, returnPage };
