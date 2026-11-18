'use strict';
const { HttpsError } = require('firebase-functions/v2/https');
const sizeOffsets = require('./size_pricing.json');

function validateRequest(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(k => !['items', 'isDelivery', 'deliveryAddress', 'expectedAmount', 'requestId'].includes(k)))
    throw new HttpsError('invalid-argument', 'Invalid order payload');
  if (!Array.isArray(data.items) || data.items.length < 1 || data.items.length > 30 ||
      typeof data.isDelivery !== 'boolean' ||
      !Number.isSafeInteger(data.expectedAmount) || data.expectedAmount <= 0 ||
      typeof data.requestId !== 'string' || !/^[a-f0-9]{32}$/.test(data.requestId))
    throw new HttpsError('invalid-argument', 'Invalid items or delivery method');
  const seen = new Set();
  for (const item of data.items) {
    if (!item || typeof item !== 'object' || Array.isArray(item) ||
        Object.keys(item).some(k => !['productId', 'size', 'quantity'].includes(k)) ||
        typeof item.productId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(item.productId) ||
        !['S', 'M', 'L'].includes(item.size) ||
        !Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 99)
      throw new HttpsError('invalid-argument', 'Invalid item');
    const key = `${item.productId}:${item.size}`;
    if (seen.has(key)) throw new HttpsError('invalid-argument', 'Duplicate item');
    seen.add(key);
  }
  if (data.isDelivery) {
    const a = data.deliveryAddress;
    if (!a || typeof a !== 'object' || Array.isArray(a) ||
        Object.keys(a).some(k => !['city', 'detailedAddress'].includes(k)) ||
        typeof a.city !== 'string' || a.city.trim().length < 1 || a.city.length > 120 ||
        typeof a.detailedAddress !== 'string' || a.detailedAddress.trim().length < 1 || a.detailedAddress.length > 300)
      throw new HttpsError('invalid-argument', 'Delivery address required');
  } else if (data.deliveryAddress != null) {
    throw new HttpsError('invalid-argument', 'Pickup cannot include address');
  }
}

async function buildOrder(data, uid, email, db, timestamp, paymentMethod = 'COD') {
  validateRequest(data);
  const ids = [...new Set(data.items.map(i => i.productId))];
  const snapshots = await db.getAll(...ids.map(id => db.collection('products').doc(id)));
  const products = new Map(snapshots.map(s => [s.id, s]));
  const categoryKeys = [...new Set(snapshots.filter(s => s.exists)
    .map(s => s.data().category).filter(key => typeof key === 'string'))];
  const categorySnapshots = await db.getAll(...categoryKeys.map(key => db.collection('categories').doc(key)));
  const categories = new Map(categorySnapshots.map(s => [s.id, s]));
  let amount = 0;
  const items = data.items.map(item => {
    const snap = products.get(item.productId);
    const product = snap && snap.exists ? snap.data() : null;
    if (!product || product.isAvailable !== true || product.isArchived === true ||
        !Number.isSafeInteger(product.price) || product.price <= 0 ||
        typeof product.name !== 'string' || !product.name)
      throw new HttpsError('failed-precondition', 'Product unavailable');
    const category = categories.get(product.category);
    if (!category?.exists || category.data().name !== product.category ||
        category.data().isActive !== true)
      throw new HttpsError('failed-precondition', 'Product category unavailable');
    const unitPrice = product.price + sizeOffsets[item.size];
    amount += unitPrice * item.quantity;
    if (!Number.isSafeInteger(amount) || amount > 1000000000)
      throw new HttpsError('invalid-argument', 'Amount out of range');
    return { productId: item.productId, productName: product.name,
      price: unitPrice, size: item.size, quantity: item.quantity };
  });
  const address = data.isDelivery ? {
    city: data.deliveryAddress.city.trim(),
    detailedAddress: data.deliveryAddress.detailedAddress.trim(),
    fullAddress: `${data.deliveryAddress.detailedAddress.trim()}, ${data.deliveryAddress.city.trim()}`,
  } : null;
  if (amount !== data.expectedAmount)
    throw new HttpsError('failed-precondition', 'Product price changed. Refresh cart and retry');
  return { userId: uid, userEmail: email || '', amount, items,
    status: 'Chờ xác nhận', orderStatus: 'Chờ xác nhận', isDelivery: data.isDelivery, deliveryAddress: address,
    createdAt: timestamp, paymentMethod,
    paymentStatus: paymentMethod === 'VNPAY' ? 'pending' : 'unpaid', isPaid: false };
}
module.exports = { validateRequest, buildOrder };
