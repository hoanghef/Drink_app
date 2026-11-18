'use strict';
const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc } = require('firebase/firestore');

let env;
const projectId = 'demo-drink-app-p0-test';
const profile = uid => ({ uid, email: `${uid}@example.com`, name: 'User', role: 'user', createdAt: '2026-01-01' });

before(async () => {
  env = await initializeTestEnvironment({ projectId,
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
    storage: { rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8') },
  });
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/u1'), profile('u1'));
    await setDoc(doc(db, 'users/u2'), profile('u2'));
    await setDoc(doc(db, 'categories/traditional'), { name: 'traditional',
      displayName: 'Coffee', order: 1, isActive: true });
    await setDoc(doc(db, 'categories/hidden'), { name: 'hidden',
      displayName: 'Hidden', order: 2, isActive: false });
    await setDoc(doc(db, 'categories/old-id'), { name: 'legacy',
      displayName: 'Legacy', order: 3, isActive: true });
    await setDoc(doc(db, 'products/p1'), { name: 'Coffee', price: 25000,
      category: 'traditional', imageUrl: 'assets/coffee.jpg', isAvailable: true });
    await setDoc(doc(db, 'orders/o1'), { userId: 'u1', amount: 25000, isPaid: false, status: 'Chờ xác nhận' });
    await setDoc(doc(db, 'orders/vnpay1'), { userId: 'u1', amount: 30000,
      paymentMethod: 'VNPAY', paymentStatus: 'pending', isPaid: false,
      status: 'Chờ xác nhận' });
  });
});
after(async () => { if (env) await env.cleanup(); });
const userDb = uid => env.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();
const adminDb = () => env.authenticatedContext('staff', { admin: true, email: 'staff@example.com' }).firestore();

test('public signup cannot claim admin and owner cannot change role or email', async () => {
  await assertFails(setDoc(doc(userDb('u3'), 'users/u3'), { ...profile('u3'), role: 'admin' }));
  await assertSucceeds(setDoc(doc(userDb('u3'), 'users/u3'), profile('u3')));
  await assertFails(updateDoc(doc(userDb('u1'), 'users/u1'), { role: 'admin' }));
  await assertFails(updateDoc(doc(userDb('u1'), 'users/u1'), { email: 'fake@example.com' }));
  await assertSucceeds(updateDoc(doc(userDb('u1'), 'users/u1'), { name: 'New name' }));
  await assertFails(getDoc(doc(userDb('u2'), 'users/u1')));
  await assertFails(updateDoc(doc(userDb('u2'), 'users/u1'), { name: 'Other' }));
});
test('only claims admin manages catalog; favorites stay private', async () => {
  await assertFails(setDoc(doc(userDb('u1'), 'products/p2'), { price: 1 }));
  await assertSucceeds(setDoc(doc(adminDb(), 'products/p2'),
    { name: 'Tea', price: 1000, category: 'traditional', imageUrl: 'assets/tea.jpg', isAvailable: true }));
  await assertFails(setDoc(doc(userDb('u1'), 'categories/c1'), { name: 'fake' }));
  await assertSucceeds(setDoc(doc(adminDb(), 'categories/coffee'),
    { name: 'coffee', displayName: 'Coffee', order: 1, isActive: true }));
  await assertFails(updateDoc(doc(adminDb(), 'categories/coffee'), { name: 'Changed' }));
  await assertSucceeds(setDoc(doc(userDb('u1'), 'favorites/u1'), { productIds: ['p1'] }));
  await assertFails(getDoc(doc(userDb('u2'), 'favorites/u1')));
});
test('orders are backend-only; owner reads, no client changes status or payment', async () => {
  await assertFails(setDoc(doc(userDb('u1'), 'orders/forged'),
    { userId: 'u1', amount: 1, isPaid: true }));
  await assertSucceeds(getDoc(doc(userDb('u1'), 'orders/o1')));
  await assertFails(getDoc(doc(userDb('u2'), 'orders/o1')));
  await assertSucceeds(getDoc(doc(adminDb(), 'orders/o1')));
  await assertFails(updateDoc(doc(userDb('u1'), 'orders/o1'), { status: 'Hoàn thành' }));
  await assertFails(updateDoc(doc(adminDb(), 'orders/o1'), { isPaid: true }));
  await assertFails(updateDoc(doc(adminDb(), 'orders/o1'), { amount: 1 }));
  await assertFails(updateDoc(doc(adminDb(), 'orders/o1'), { status: 'Đang pha chế' }));
  await assertFails(updateDoc(doc(adminDb(), 'orders/o1'), { paymentStatus: 'paid' }));
  await assertFails(deleteDoc(doc(adminDb(), 'orders/o1')));
  await assertFails(updateDoc(doc(adminDb(), 'orders/vnpay1'), { status: 'Đang giao' }));
  await assertFails(setDoc(doc(adminDb(), 'vnpayRefs/opaque'), { orderId: 'vnpay1' }));
  await assertFails(setDoc(doc(adminDb(), 'vnpayTransactions/123'), { orderId: 'vnpay1' }));
  await assertFails(getDoc(doc(userDb('u1'), 'vnpayRefs/opaque')));
});
test('storage writes require admin claim, image path and content type', async () => {
  const bytes = new Uint8Array([1, 2, 3]);
  await assertFails(env.authenticatedContext('u1').storage()
    .ref('products/p1.jpg').put(bytes, { contentType: 'image/jpeg' }));
  await assertFails(env.authenticatedContext('staff', { admin: true }).storage()
    .ref('other/file.jpg').put(bytes, { contentType: 'image/jpeg' }));
  await assertFails(env.authenticatedContext('staff', { admin: true }).storage()
    .ref('products/p1.jpg').put(bytes, { contentType: 'text/plain' }));
  await assertSucceeds(env.authenticatedContext('staff', { admin: true }).storage()
    .ref('products/p1.jpg').put(bytes, { contentType: 'image/jpeg' }));
  await assertSucceeds(env.authenticatedContext('staff', { admin: true }).storage()
    .ref('products/p1_12345.jpg').put(bytes, { contentType: 'image/jpeg' }));
  await assertFails(env.authenticatedContext('staff', { admin: true }).storage()
    .ref('products/p1.jpg').put(bytes, { contentType: 'image/png' }));
  await assertFails(env.authenticatedContext('staff', { admin: true }).storage()
    .ref('products/too-large.jpg').put(new Uint8Array(5 * 1024 * 1024),
      { contentType: 'image/jpeg' }));
  await assertFails(env.authenticatedContext('staff', { admin: true }).storage()
    .ref('products/p1.jpg').delete());
});
test('catalog CRUD requires claim; category key immutable and deletes denied', async () => {
  await assertFails(updateDoc(doc(userDb('u1'), 'products/p1'), { price: 1 }));
  await assertSucceeds(updateDoc(doc(adminDb(), 'products/p1'), { price: 28000 }));
  await assertFails(deleteDoc(doc(userDb('u1'), 'products/p1')));
  await assertSucceeds(updateDoc(doc(adminDb(), 'products/p1'), { isArchived: true, isAvailable: false }));
  await assertSucceeds(updateDoc(doc(adminDb(), 'categories/coffee'), { isActive: false, order: 2 }));
  await assertFails(updateDoc(doc(userDb('u1'), 'categories/coffee'), { isActive: true }));
  await assertFails(deleteDoc(doc(adminDb(), 'categories/coffee')));
  await assertFails(setDoc(doc(adminDb(), 'categories/bad'),
    { name: 'bad', displayName: '', order: 0, isActive: true }));
  await assertFails(setDoc(doc(adminDb(), 'products/bad'),
    { name: 'Invalid', price: -1, category: 'coffee', isAvailable: true }));
  await assertFails(updateDoc(doc(adminDb(), 'products/p1'), { price: 0 }));
  await assertFails(deleteDoc(doc(adminDb(), 'products/p1')));
});
test('product writes require an active canonical category', async () => {
  const product = { name: 'Sample', price: 25000, imageUrl: 'assets/coffee.jpg',
    isAvailable: true };
  await assertSucceeds(setDoc(doc(adminDb(), 'products/valid-category'),
    { ...product, category: 'traditional' }));
  await assertFails(setDoc(doc(adminDb(), 'products/missing-category'),
    { ...product, category: 'missing' }));
  await assertFails(setDoc(doc(adminDb(), 'products/hidden-category'),
    { ...product, category: 'hidden' }));
  await assertFails(setDoc(doc(adminDb(), 'products/legacy-category'),
    { ...product, category: 'legacy' }));
  await assertFails(setDoc(doc(adminDb(), 'products/fractional-price'),
    { ...product, price: 25000.5, category: 'traditional' }));
  await assertFails(updateDoc(doc(adminDb(), 'products/valid-category'),
    { category: 'hidden' }));
  await assertFails(updateDoc(doc(adminDb(), 'products/valid-category'),
    { category: 'missing' }));
});
test('category document ID must equal its immutable key', async () => {
  const category = { name: 'sample', displayName: 'Sample', order: 4, isActive: true };
  await assertFails(setDoc(doc(adminDb(), 'categories/wrong-id'), category));
  await assertSucceeds(setDoc(doc(adminDb(), 'categories/sample'), category));
  await assertFails(updateDoc(doc(adminDb(), 'categories/sample'), { name: 'other' }));
  await assertFails(updateDoc(doc(adminDb(), 'categories/old-id'), { order: 5 }));
});
