'use strict';
const { onCall, onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { isIP } = require('node:net');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { placeOrder } = require('./place_order');
const { credentialsReady, configured, createVnpayPayment, processVnpayIpn, returnPage } = require('./vnpay');
const { updateOrderStatus, collectCodPayment } = require('./admin_orders');
const { reconcileVnpayPayment } = require('./vnpay_reconcile');
initializeApp();
const tmnCode = defineSecret('VNPAY_TMN_CODE');
const hashSecret = defineSecret('VNPAY_HASH_SECRET');
const vnpaySecrets = [tmnCode, hashSecret];
function vnpayConfig() {
  return { enabled: process.env.VNPAY_ENABLED === 'true',
    tmnCode: tmnCode.value(), hashSecret: hashSecret.value(),
    ipnUrl: process.env.VNPAY_IPN_URL, returnUrl: process.env.VNPAY_RETURN_URL,
    orderType: process.env.VNPAY_ORDER_TYPE || 'other',
    queryEnabled: process.env.VNPAY_QUERY_ENABLED === 'true',
    serverIp: process.env.VNPAY_SERVER_IP };
}
exports.placeOrder = onCall({ region: 'asia-southeast1' }, request =>
  placeOrder(request.data, request.auth, getFirestore(), FieldValue.serverTimestamp()));
exports.updateOrderStatus = onCall({ region: 'asia-southeast1' }, request =>
  updateOrderStatus(request.data, request.auth, getFirestore(), FieldValue.serverTimestamp()));
exports.collectCodPayment = onCall({ region: 'asia-southeast1' }, request =>
  collectCodPayment(request.data, request.auth, getFirestore(), FieldValue.serverTimestamp()));
exports.vnpayAvailability = onCall({ region: 'asia-southeast1', secrets: vnpaySecrets }, () =>
  ({ enabled: configured(vnpayConfig()),
    queryEnabled: credentialsReady(vnpayConfig()) &&
      process.env.VNPAY_QUERY_ENABLED === 'true' &&
      isIP(process.env.VNPAY_SERVER_IP || '') !== 0 }));
exports.createVnpayPayment = onCall({ region: 'asia-southeast1', secrets: vnpaySecrets }, request =>
  createVnpayPayment(request.data, request.auth, getFirestore(),
    FieldValue.serverTimestamp(), vnpayConfig(), request.rawRequest.ip));
exports.reconcileVnpayPayment = onCall({ region: 'asia-southeast1',
  secrets: vnpaySecrets, timeoutSeconds: 30 }, request =>
  reconcileVnpayPayment(request.data, request.auth, getFirestore(),
    vnpayConfig(), FieldValue.serverTimestamp()));
exports.vnpayIpn = onRequest({ region: 'asia-southeast1', secrets: vnpaySecrets }, async (req, res) => {
  if (req.method !== 'GET') {
    res.status(405).end(); return;
  }
  try {
    const result = await processVnpayIpn(req.query, getFirestore(), vnpayConfig(),
      FieldValue.serverTimestamp());
    res.status(200).json(result);
  } catch (error) {
    console.error('VNPay IPN rejected:', error.message);
    res.status(200).json({ RspCode: '99', Message: 'System error' });
  }
});
exports.vnpayReturn = onRequest({ region: 'asia-southeast1' }, (req, res) => {
  if (req.method !== 'GET') { res.status(405).end(); return; }
  res.set('Cache-Control', 'no-store');
  res.status(200).type('html').send(returnPage());
});
