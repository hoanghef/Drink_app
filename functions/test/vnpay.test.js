'use strict';
// Gateway calls are injected; the real Sandbox is never contacted by tests.
global.fetch = async () => { throw new Error('Real gateway calls are forbidden in tests'); };
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createVnpayPayment, processVnpayIpn, encoded, sign, returnPage } = require('../vnpay');
const { reconcileVnpayPayment, responseChecksumRaw, minimumIntervalMs } = require('../vnpay_reconcile');

const config = { enabled: true, tmnCode: 'TEST1234', hashSecret: 'dummy-test-key-only',
  ipnUrl: 'https://example.test/ipn', returnUrl: 'https://example.test/return',
  orderType: 'other', queryEnabled: true, serverIp: '127.0.0.1' };
const request = { requestId: '0123456789abcdef0123456789abcdef', expectedAmount: 30000,
  items: [{ productId: 'p1', size: 'M', quantity: 1 }],
  isDelivery: false, deliveryAddress: null };
const user = { uid: 'user-a', token: { email: 'user@example.test' } };
const admin = { uid: 'staff', token: { admin: true } };
const at = new Date('2026-11-18T08:00:00.000Z');

test('signature input sorts keys and form-encodes spaces and reserved characters', () => {
  assert.equal(encoded({ vnp_TxnRef: 'a+b', vnp_OrderInfo: 'Drink order 1',
    vnp_SecureHashType: 'SHA512' }),
  'vnp_OrderInfo=Drink+order+1&vnp_TxnRef=a%2Bb');
});

function fixture() {
  const orders = new Map(), refs = new Map(), transactions = new Map(), audit = [];
  const store = name => ({ orders, vnpayRefs: refs,
    vnpayTransactions: transactions })[name];
  const ref = (name, id) => ({ name, id,
    get: async () => ({ exists: store(name).has(id), data: () => store(name).get(id) }),
    collection: () => ({ doc: () => ({ name: 'audit', id: `${audit.length}` }) }),
  });
  const getAll = async (...items) => items.map(item => ({ id: item.id, exists: true,
    data: () => item.name === 'categories'
      ? { name: 'traditional', isActive: true }
      : { name: 'Coffee', price: 25000, category: 'traditional', isAvailable: true } }));
  const db = { collection: name => ({ doc: id => ref(name, id) }), getAll,
    runTransaction: async fn => fn({
      get: item => item.get(), getAll,
      create: (item, value) => item.name === 'audit'
        ? audit.push(value) : store(item.name).set(item.id, value),
      update: (item, value) => store(item.name).set(item.id,
        { ...store(item.name).get(item.id), ...value }),
    }) };
  return { db, orders, refs, transactions, audit };
}
async function create(f, data = request, transactionRef = 'a'.repeat(32)) {
  return createVnpayPayment(data, user, f.db, 'server-time', config, '127.0.0.1',
    at, () => transactionRef);
}
function callback(f, orderId, changes = {}) {
  const order = f.orders.get(orderId);
  const params = { vnp_Amount: '3000000', vnp_BankCode: 'NCB',
    vnp_OrderInfo: order?.vnpOrderInfo || `Drink order ${'a'.repeat(32)}`,
    vnp_PayDate: '20261118151000', vnp_ResponseCode: '00',
    vnp_TmnCode: config.tmnCode, vnp_TransactionNo: '123456',
    vnp_TransactionStatus: '00', vnp_TxnRef: order?.vnpTxnRef || 'b'.repeat(32),
    ...changes };
  params.vnp_SecureHash = sign(encoded(params), config.hashSecret);
  return params;
}
function querySender(changes = {}) {
  return async (url, options) => {
    assert.equal(url, 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction');
    assert.equal(options.method, 'POST');
    const body = JSON.parse(options.body);
    const raw = ['vnp_RequestId', 'vnp_Version', 'vnp_Command', 'vnp_TmnCode',
      'vnp_TxnRef', 'vnp_TransactionDate', 'vnp_CreateDate', 'vnp_IpAddr',
      'vnp_OrderInfo'].map(key => body[key]).join('|');
    assert.equal(body.vnp_SecureHash, sign(raw, config.hashSecret));
    const response = { vnp_ResponseId: 'response1', vnp_Command: 'querydr',
      vnp_ResponseCode: '00', vnp_Message: 'Query Success',
      vnp_TmnCode: body.vnp_TmnCode, vnp_TxnRef: body.vnp_TxnRef,
      vnp_Amount: '3000000', vnp_BankCode: 'NCB',
      vnp_PayDate: '20261118151000', vnp_TransactionNo: '123456',
      vnp_TransactionType: '01', vnp_TransactionStatus: '00',
      vnp_OrderInfo: body.vnp_OrderInfo, ...changes };
    response.vnp_SecureHash = sign(responseChecksumRaw(response), config.hashSecret);
    if (changes.vnp_SecureHash) response.vnp_SecureHash = changes.vnp_SecureHash;
    return { ok: true, json: async () => response };
  };
}
async function reconcile(f, orderId, send = querySender(), time = 1000000) {
  return reconcileVnpayPayment({ orderId }, admin, f.db, config, 'server-time',
    send, () => time, () => 'c'.repeat(32));
}

test('URL uses 2.1.0 HMACSHA512, VND times 100, opaque ref and retry reuses order', async () => {
  const f = fixture();
  const first = await create(f);
  const url = new URL(first.payUrl);
  assert.equal(url.origin + url.pathname, 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html');
  assert.equal(url.searchParams.get('vnp_Amount'), '3000000');
  assert.equal(url.searchParams.get('vnp_Version'), '2.1.0');
  assert.equal(url.searchParams.get('vnp_TxnRef'), 'a'.repeat(32));
  assert(!first.payUrl.includes(user.uid));
  assert(!first.payUrl.includes(user.token.email));
  assert(!url.searchParams.has('vnp_SecureHashType'));
  assert.equal(url.searchParams.get('vnp_SecureHash'),
    sign(encoded(Object.fromEntries(url.searchParams)), config.hashSecret));
  assert.equal(f.orders.get(first.orderId).paymentStatus, 'pending');
  assert.deepEqual(await create(f), first);
  assert.equal(f.orders.size, 1);
  assert.equal(f.refs.size, 1);
});

test('valid signed IPN pays once; wrong hash, amount, reference and order cannot pay', async () => {
  const f = fixture();
  const { orderId } = await create(f);
  assert.equal((await processVnpayIpn({ ...callback(f, orderId),
    vnp_SecureHash: '0'.repeat(128) }, f.db, config, 'now')).RspCode, '97');
  assert.equal((await processVnpayIpn(callback(f, orderId, { vnp_Amount: '1' }),
    f.db, config, 'now')).RspCode, '04');
  assert.equal((await processVnpayIpn(callback(f, orderId, { vnp_TxnRef: 'b'.repeat(32) }),
    f.db, config, 'now')).RspCode, '01');
  assert.equal((await processVnpayIpn(callback(f, orderId, { vnp_OrderInfo: 'Wrong' }),
    f.db, config, 'now')).RspCode, '99');
  assert.equal((await processVnpayIpn(callback(f, orderId, { vnp_TmnCode: 'OTHER123' }),
    f.db, config, 'now')).RspCode, '99');
  assert.equal(f.orders.get(orderId).paymentStatus, 'pending');
  assert.equal((await processVnpayIpn(callback(f, orderId), f.db, config, 'now')).RspCode, '00');
  assert.equal(f.orders.get(orderId).paymentStatus, 'paid');
  assert.equal(f.transactions.get('123456').orderId, orderId);
  assert.equal((await processVnpayIpn(callback(f, orderId), f.db, config, 'later')).RspCode, '02');
  assert.equal(f.audit.length, 1);
});

test('IPN still settles a pending order after new payments are disabled', async () => {
  const f = fixture();
  const { orderId } = await create(f);
  assert.equal((await processVnpayIpn(callback(f, orderId), f.db,
    { ...config, enabled: false }, 'later')).RspCode, '00');
  assert.equal(f.orders.get(orderId).paymentStatus, 'paid');
});

test('one gateway transaction number cannot pay two orders', async () => {
  const f = fixture();
  const first = await create(f);
  const second = await create(f, { ...request, requestId: 'b'.repeat(32) },
    'b'.repeat(32));
  await processVnpayIpn(callback(f, first.orderId), f.db, config, 'now');
  assert.equal((await processVnpayIpn(callback(f, second.orderId), f.db,
    config, 'later')).RspCode, '99');
  assert.equal(f.orders.get(second.orderId).paymentStatus, 'pending');
});

test('failed, canceled, ambiguous, timeout and browser return never mark paid', async () => {
  for (const [fields, status] of [
    [{ vnp_ResponseCode: '99', vnp_TransactionStatus: '02' }, 'failed'],
    [{ vnp_ResponseCode: '24', vnp_TransactionStatus: '02' }, 'canceled'],
    [{ vnp_ResponseCode: '07', vnp_TransactionStatus: '07' }, 'pending'],
    [{ vnp_ResponseCode: '00', vnp_TransactionStatus: '01' }, 'pending'],
  ]) {
    const f = fixture();
    const { orderId } = await create(f);
    await processVnpayIpn(callback(f, orderId, fields), f.db, config, 'now');
    assert.equal(f.orders.get(orderId).paymentStatus, status);
    assert.equal(f.orders.get(orderId).isPaid, false);
  }
  const f = fixture();
  const { orderId } = await create(f);
  assert.match(returnPage(), /quay lại ứng dụng/);
  assert.equal(f.orders.get(orderId).paymentStatus, 'pending');
  assert.equal(f.audit.length, 0);
  // A signed callback arriving later can still settle a pending order.
  await processVnpayIpn(callback(f, orderId), f.db, config, 'later');
  assert.equal(f.orders.get(orderId).paymentStatus, 'paid');
});

test('late success after signed cancellation does not silently reopen payment', async () => {
  const f = fixture();
  const { orderId } = await create(f);
  await processVnpayIpn(callback(f, orderId,
    { vnp_ResponseCode: '24', vnp_TransactionStatus: '02' }),
  f.db, config, 'canceled-at');
  assert.equal((await processVnpayIpn(callback(f, orderId),
    f.db, config, 'later')).RspCode, '02');
  assert.equal(f.orders.get(orderId).paymentStatus, 'canceled');
  assert.equal(f.audit.length, 1);
});

test('invalid configuration and forged client payment fields create no paid order', async () => {
  const f = fixture();
  await assert.rejects(createVnpayPayment(request, user, f.db, 'now',
    { ...config, hashSecret: '' }, '127.0.0.1'));
  assert.equal(f.orders.size, 0);
  await assert.rejects(create(f, { ...request, isPaid: true }));
  assert.equal(f.orders.size, 0);
});

test('QUERYDR verifies signed response and pays idempotently; late IPN is duplicate', async () => {
  const f = fixture();
  const { orderId } = await create(f);
  assert.equal((await reconcile(f, orderId)).paymentStatus, 'paid');
  assert.equal(f.orders.get(orderId).paymentStatus, 'paid');
  assert.equal((await reconcile(f, orderId, async () => { throw new Error('must not call'); })).alreadyRecorded, true);
  assert.equal((await processVnpayIpn(callback(f, orderId), f.db, config, 'later')).RspCode, '02');
  assert.equal(f.audit.filter(x => x.action === 'vnpayReconcile').length, 1);
});

test('QUERYDR rejects user, bad signature, amount and reference; leaves pending', async () => {
  for (const change of [{ vnp_Amount: '1' }, { vnp_TxnRef: 'wrong' },
    { vnp_SecureHash: '0'.repeat(128) }]) {
    const f = fixture();
    const { orderId } = await create(f);
    await assert.rejects(reconcileVnpayPayment({ orderId }, user, f.db, config,
      'now', querySender(), () => 1000000));
    await assert.rejects(reconcile(f, orderId, querySender(change)));
    assert.equal(f.orders.get(orderId).paymentStatus, 'pending');
  }
});

test('QUERYDR pending, timeout and rate limit never close payment', async () => {
  const f = fixture();
  const { orderId } = await create(f);
  const pending = await reconcile(f, orderId,
    querySender({ vnp_TransactionStatus: '01', vnp_TransactionNo: '0' }));
  assert.equal(pending.paymentStatus, 'pending');
  await assert.rejects(reconcile(f, orderId, querySender(), 1000001));
  await assert.rejects(reconcile(f, orderId, async () => { throw new Error('timeout'); },
    1000000 + minimumIntervalMs));
  assert.equal(f.orders.get(orderId).paymentStatus, 'pending');
});

test('disabled QUERYDR leaves payment pending without contacting gateway', async () => {
  const f = fixture();
  const { orderId } = await create(f);
  await assert.rejects(reconcileVnpayPayment({ orderId }, admin, f.db,
    { ...config, queryEnabled: false }, 'now',
    async () => { throw new Error('Gateway must not be contacted'); }));
  assert.equal(f.orders.get(orderId).paymentStatus, 'pending');
});

test('late IPN wins QUERYDR race; query cannot overwrite it', async () => {
  const f = fixture();
  const { orderId } = await create(f);
  const send = async (url, options) => {
    await processVnpayIpn(callback(f, orderId), f.db, config, 'ipn-time');
    return querySender()(url, options);
  };
  assert.equal((await reconcile(f, orderId, send)).alreadyRecorded, true);
  assert.equal(f.orders.get(orderId).paymentStatus, 'paid');
});
