'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { planSeed, categories, products } = require('../seed_catalog');

test('empty catalog seeds canonical categories before products and is idempotent', () => {
  const first = planSeed(new Map(), new Map());
  assert.equal(first.creates.length, categories.length + products.length);
  assert.equal(first.updates.length, 0);
  const seededCategories = new Map(first.creates.filter(x => x.collection === 'categories')
    .map(x => [x.id, x.data]));
  const seededProducts = new Map(first.creates.filter(x => x.collection === 'products')
    .map(x => [x.id, x.data]));
  for (const [id, value] of seededCategories) assert.equal(id, value.name);
  assert.deepEqual(planSeed(seededCategories, seededProducts),
    { creates: [], updates: [], skippedProducts: [] });
});

test('legacy category IDs migrate without deleting documents or overwriting edits', () => {
  const old = { name: 'traditional', displayName: 'Edited label', order: 7, isActive: true };
  const existing = new Map([['ca-phe-truyen-thong', old]]);
  const plan = planSeed(existing, new Map());
  const canonical = plan.creates.find(x => x.collection === 'categories' && x.id === 'traditional');
  assert.deepEqual(canonical.data, old);
  assert.deepEqual(plan.updates, [{ collection: 'categories',
    id: 'ca-phe-truyen-thong', data: { isActive: false } }]);
  existing.set('traditional', canonical.data);
  existing.set('ca-phe-truyen-thong', { ...old, isActive: false });
  assert.equal(planSeed(existing, new Map()).updates.length, 0);
});

test('inactive category is preserved and its missing products are skipped', () => {
  const existing = new Map([['milk', { name: 'milk', displayName: 'Hidden',
    order: 2, isActive: false }]]);
  const plan = planSeed(existing, new Map());
  assert(plan.skippedProducts.includes('bac-xiu'));
  assert(!plan.creates.some(x => x.collection === 'products' && x.id === 'bac-xiu'));
  assert(!plan.creates.some(x => x.collection === 'categories' && x.id === 'milk'));
});

test('conflicting canonical keys and duplicate legacy keys stop the seed', () => {
  assert.throws(() => planSeed(new Map([['traditional', { name: 'other' }]]), new Map()));
  assert.throws(() => planSeed(new Map([
    ['old-1', { name: 'traditional', isActive: true }],
    ['old-2', { name: 'traditional', isActive: true }],
  ]), new Map()));
});
