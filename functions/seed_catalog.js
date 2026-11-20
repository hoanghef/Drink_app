'use strict';
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const categories = [
  { name: 'traditional', displayName: 'Cà phê truyền thống', order: 1, isActive: true },
  { name: 'milk', displayName: 'Cà phê sữa & béo', order: 2, isActive: true },
  { name: 'espresso', displayName: 'Cà phê Ý (Espresso)', order: 3, isActive: true },
  { name: 'special', displayName: 'Cà phê đặc biệt', order: 4, isActive: true },
];
const products = [
  ['den-da', 'Đen đá', 15000, 'traditional', 'cafedenda.png'],
  ['sua-da', 'Sữa đá', 18000, 'traditional', 'cafesuada.jpg'],
  ['bac-xiu', 'Bạc xỉu', 20000, 'milk', 'bacxiu.jpg'],
  ['espresso', 'Espresso', 35000, 'espresso', 'espresso.jpg'],
  ['americano', 'Americano', 38000, 'espresso', 'americano.jpg'],
  ['cappuccino', 'Cappuccino', 45000, 'espresso', 'cappuccino.jpg'],
  ['latte', 'Latte', 48000, 'espresso', 'latte.jpg'],
  ['cold-brew', 'Cold Brew', 42000, 'special', 'coldbrew.jpg'],
  ['ca-phe-trung', 'Cà phê trứng', 35000, 'special', 'cafetrung.jpg'],
  ['da-xay', 'Đá xay', 40000, 'special', 'mocha.jpg'],
].map(([id, name, price, category, image]) => ({ id, name, price, category,
  description: name, imageUrl: `assets/images/${image}`,
  imageURL: `assets/images/${image}`, rating: 0,
  isAvailable: true, isArchived: false }));

function planSeed(existingCategories, existingProducts, { categoriesOnly = false } = {}) {
  const creates = [], updates = [], skippedProducts = [];
  const categoryState = new Map();
  for (const category of categories) {
    const key = category.name;
    const current = existingCategories.get(key);
    if (current && current.name !== key) {
      throw new Error(`Category document ${key} has a different key; resolve it manually`);
    }
    const legacy = [...existingCategories].filter(([id, value]) =>
      id !== key && value.name === key);
    if (legacy.length > 1) {
      throw new Error(`Multiple legacy category documents use key ${key}`);
    }
    if (!current) {
      const source = legacy[0]?.[1] || category;
      const data = { name: key, displayName: source.displayName,
        order: source.order, isActive: source.isActive === true };
      creates.push({ collection: 'categories', id: key, data });
      categoryState.set(key, data);
    } else {
      categoryState.set(key, current);
    }
    if (legacy.length && legacy[0][1].isActive === true) {
      updates.push({ collection: 'categories', id: legacy[0][0],
        data: { isActive: false } });
    }
  }
  if (!categoriesOnly) {
    for (const product of products) {
      if (existingProducts.has(product.id)) continue;
      if (categoryState.get(product.category)?.isActive !== true) {
        skippedProducts.push(product.id);
        continue;
      }
      creates.push({ collection: 'products', id: product.id, data: product });
    }
  }
  return { creates, updates, skippedProducts };
}

function snapshotMap(snapshot) {
  return new Map(snapshot.docs.map(doc => [doc.id, doc.data()]));
}

async function runSeed(db, apply, options = {}) {
  if (!apply) {
    const [categorySnapshot, productSnapshot] = await Promise.all([
      db.collection('categories').get(), db.collection('products').get(),
    ]);
    return planSeed(snapshotMap(categorySnapshot), snapshotMap(productSnapshot), options);
  }
  return db.runTransaction(async transaction => {
    const [categorySnapshot, productSnapshot] = await Promise.all([
      transaction.get(db.collection('categories')),
      transaction.get(db.collection('products')),
    ]);
    const plan = planSeed(snapshotMap(categorySnapshot), snapshotMap(productSnapshot), options);
    for (const item of plan.creates) {
      transaction.create(db.collection(item.collection).doc(item.id), item.data);
    }
    for (const item of plan.updates) {
      transaction.update(db.collection(item.collection).doc(item.id), item.data);
    }
    return plan;
  });
}

async function main(args) {
  const projectIndex = args.indexOf('--project');
  const projectId = projectIndex >= 0 ? args[projectIndex + 1] : null;
  const apply = args.includes('--apply');
  const categoriesOnly = args.includes('--categories-only');
  const allowed = args.every((arg, index) =>
    arg === '--project' || arg === '--apply' || arg === '--dry-run' ||
    arg === '--categories-only' ||
    (index === projectIndex + 1 && arg === projectId));
  if (!projectId || !/^[a-z][a-z0-9-]{4,62}$/.test(projectId) ||
      !allowed || (apply && args.includes('--dry-run'))) {
    throw new Error('Usage: node seed_catalog.js --project <project-id> [--categories-only] [--dry-run | --apply]');
  }
  initializeApp({ projectId, ...(process.env.FIRESTORE_EMULATOR_HOST ? {} :
    { credential: applicationDefault() }) });
  const plan = await runSeed(getFirestore(), apply, { categoriesOnly });
  console.log(`${apply ? 'Applied' : 'Dry run'} on ${projectId}: ` +
    `${plan.creates.length} creates, ${plan.updates.length} legacy category hides, ` +
    `${plan.skippedProducts.length} products skipped (inactive category).`);
  for (const item of [...plan.creates, ...plan.updates]) {
    console.log(`${item.collection}/${item.id}: ${plan.creates.includes(item) ? 'create' : 'hide legacy'}`);
  }
  for (const id of plan.skippedProducts) console.log(`products/${id}: skipped`);
}

if (require.main === module) {
  main(process.argv.slice(2)).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
module.exports = { categories, products, planSeed, runSeed };
