const admin = require('../functions/node_modules/firebase-admin');

const serviceAccount = require('../perfume-orders-worker/service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();
const { Timestamp } = admin.firestore;

const IMAGE_POOL = [
  'https://pub-578625c66b1749c2b5b2e0c0a89a26b5.r2.dev/products/2026-04-10/84f89219-89d6-4f22-a0b8-273ae0216d17-3333.png',
  'https://pub-578625c66b1749c2b5b2e0c0a89a26b5.r2.dev/products/2026-04-10/a5f202fe-e18f-4fa9-b518-8b6a9a045bca-444.png',
  'https://pub-578625c66b1749c2b5b2e0c0a89a26b5.r2.dev/products/2026-04-10/f71cec69-b7c4-4224-8cb3-72da6653a6c7-222222.png',
  'https://pub-578625c66b1749c2b5b2e0c0a89a26b5.r2.dev/products/2026-04-10/f778fba1-b5d7-4e60-b873-7e0f301372ad-111111.png',
];
const SIZE_POOL = ['30 ml', '50 ml', '75 ml', '100 ml', '125 ml', '150 ml'];

const STOP_WORDS = new Set([
  'de', 'of', 'the', 'and', 'for', 'a', 'an', 'eau',
  'by', 'le', 'la', 'les', 'du', 'des', 'en', 'et',
  'or', 'with', 'from',
]);

function buildSearchPrefixes(name) {
  const cleaned = name
    .toLowerCase()
    .replace(/[^\w\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  const words = cleaned
    .split(' ')
    .filter((word) => word.length >= 2 && !STOP_WORDS.has(word));

  const prefixes = new Set();
  for (const word of words) {
    for (let i = 2; i <= word.length; i += 1) {
      prefixes.add(word.substring(0, i));
    }
  }

  return [...prefixes];
}

function normalizeQueryKey(value) {
  return String(value || '')
    .toLowerCase()
    .trim()
    .replace(/[\u064B-\u0652\u0670]/g, '')
    .replace(/\u0640/g, '')
    .replace(/[\u0623\u0625\u0622]/g, '\u0627')
    .replace(/\u0649/g, '\u064a')
    .replace(/\u0624/g, '\u0648')
    .replace(/\u0626/g, '\u064a')
    .replace(/\u0629/g, '\u0647')
    .replace(/[^\w\s\u0621-\u064A\u0660-\u0669]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function pick(list, index) {
  return list[index % list.length];
}

function pickImage(index) {
  return IMAGE_POOL[index % IMAGE_POOL.length];
}

function pickSize(index) {
  return SIZE_POOL[index % SIZE_POOL.length];
}

function buildProducts() {
  const names = [
    'Velvet Amber Bloom',
    'Citrus Sand Whisper',
    'Midnight Oud Trace',
    'Rose Musk Veil',
    'Golden Spice Route',
    'Ocean Cedar Pulse',
    'Vanilla Smoke Halo',
    'White Floral Echo',
    'Fresh Linen Drift',
    'Ruby Berry Mist',
    'Saffron Noir Touch',
    'Soft Powder Silk',
    'Jasmine Wood Aura',
    'Silver Marine Light',
    'Honey Amber Dusk',
    'Crystal Citrus Air',
    'Dark Resin Story',
    'Blooming Pearl',
    'Urban Musk Signal',
    'Desert Night Code',
    'Moonlit Petals',
    'Cedar Spice Focus',
    'Amber Vanilla Note',
    'Blue Aqua Trail',
    'Velvet Rose Flame',
    'Clean Musk Hour',
    'Oud Leather Frame',
    'Sunny Citrus Pop',
    'Floral Cashmere Mood',
    'Warm Sand Elixir',
  ];

  const brands = [
    'Noura Atelier',
    'Maison Rayah',
    'Desert Muse',
    'Amber District',
    'Velvet Loom',
    'Scent Theory',
  ];
  const genders = ['men', 'women', 'unisex'];
  const seasons = ['summer', 'winter', 'spring', 'autumn', 'all_seasons'];
  const occasions = ['daily', 'formal', 'evening', 'casual', 'office', 'date', 'university'];
  const times = ['day', 'night', 'all_day'];
  const intensities = ['light', 'medium', 'strong'];
  const families = [
    'fresh citrus',
    'woody spicy',
    'amber gourmand',
    'floral musk',
    'aquatic fresh',
    'oud woody',
  ];
  const noteSets = [
    ['amber', 'vanilla', 'musk'],
    ['citrus', 'aquatic', 'cedar'],
    ['oud', 'saffron', 'leather'],
    ['rose', 'jasmine', 'musk'],
    ['berry', 'floral', 'amber'],
    ['powdery', 'cashmere', 'musk'],
    ['marine', 'citrus', 'woody'],
    ['spicy', 'resin', 'vanilla'],
    ['floral', 'pear', 'white musk'],
    ['cedar', 'smoke', 'amber'],
  ];

  const baseDate = new Date('2026-04-10T09:00:00Z');

  return names.map((name, index) => {
    const notes = pick(noteSets, index);
    const topNotes = [notes[0]];
    const middleNotes = [notes[1]];
    const baseNotes = [notes[2]];
    const price = 790 + (index * 65);
    const stock = 7 + (index % 19);
    const createdAt = new Date(baseDate.getTime() + index * 60000);
    return {
      id: `catalog_refresh_${String(index + 1).padStart(2, '0')}`,
      name,
      brand: pick(brands, index),
      price,
      stock,
      size: pickSize(index),
      gender: pick(genders, index),
      season: pick(seasons, index),
      fragranceFamily: pick(families, index),
      notes,
      imageUrls: [pickImage(index)],
      description: `${name} is a refreshed catalog perfume with a balanced profile suitable for modern retail browsing and AI recommendation flows.`,
      categoryName: 'Perfumes',
      createdAt: Timestamp.fromDate(createdAt),
      updatedAt: Timestamp.now(),
      occasion: pick(occasions, index),
      time: pick(times, index),
      intensity: pick(intensities, index),
      topNotes,
      middleNotes,
      baseNotes,
      tags: [...new Set([notes[0], notes[1], notes[2], pick(intensities, index), pick(occasions, index)])],
      pyramidDescription: `Top: ${topNotes.join(', ')}. Middle: ${middleNotes.join(', ')}. Base: ${baseNotes.join(', ')}.`,
    };
  });
}

async function deleteAllProducts() {
  let deleted = 0;

  while (true) {
    const snapshot = await db.collection('products').limit(200).get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.size;
    console.log(`Deleted ${deleted} products so far...`);
  }

  return deleted;
}

async function seedProducts(products) {
  let committed = 0;

  for (let i = 0; i < products.length; i += 200) {
    const chunk = products.slice(i, i + 200);
    const batch = db.batch();
    for (const product of chunk) {
      const ref = db.collection('products').doc(product.id);
      batch.set(ref, {
        ...product,
        nameLower: product.name.toLowerCase(),
        searchPrefixes: buildSearchPrefixes(product.name),
        categoryKey: normalizeQueryKey(product.categoryName),
        fragranceFamilyKey: normalizeQueryKey(product.fragranceFamily),
        isActive: product.isActive ?? true,
        saleActive:
          Number(product.salePrice || 0) > 0 &&
          Number(product.salePrice || 0) < Number(product.price || 0),
      });
    }
    await batch.commit();
    committed += chunk.length;
  }

  return committed;
}

async function main() {
  console.log(`Project: ${serviceAccount.project_id}`);
  console.log('Deleting all existing products...');
  const deleted = await deleteAllProducts();

  const products = buildProducts();
  console.log('Seeding 30 new products...');
  const inserted = await seedProducts(products);

  const finalSnapshot = await db.collection('products').get();
  console.log(`Deleted: ${deleted}`);
  console.log(`Inserted: ${inserted}`);
  console.log(`Final count: ${finalSnapshot.size}`);
  for (const doc of finalSnapshot.docs) {
    const data = doc.data();
    console.log(`${doc.id} -> ${data.name} -> ${data.imageUrls?.[0] ?? 'no-image'}`);
  }
}

main().catch((error) => {
  console.error('Failed to reset products catalog.');
  console.error(error);
  process.exitCode = 1;
});
