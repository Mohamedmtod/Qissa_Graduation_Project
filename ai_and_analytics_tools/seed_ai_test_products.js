const admin = require('../functions/node_modules/firebase-admin');

const serviceAccount = require('../perfume-orders-worker/service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();
const { Timestamp } = admin.firestore;

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

function imageUrl(label) {
  return `https://placehold.co/600x800/png?text=${encodeURIComponent(label)}`;
}

const baseDate = new Date('2026-03-31T00:00:00Z');

const products = [
  {
    id: 'ai_test_amber_vanilla_mist',
    name: 'Amber Vanilla Mist',
    brand: 'Test Lab',
    price: 1399,
    stock: 18,
    gender: 'women',
    season: 'winter',
    fragranceFamily: 'amber gourmand',
    notes: ['vanilla', 'amber', 'musk'],
    topNotes: ['citrus'],
    middleNotes: ['floral', 'rose'],
    baseNotes: ['vanilla', 'amber', 'musk'],
    tags: ['sweet', 'warm', 'elegant'],
    occasion: 'evening',
    time: 'night',
    intensity: 'medium',
    description: 'Sweet amber-vanilla profile for winter evenings with a soft musky drydown.',
  },
  {
    id: 'ai_test_campus_citrus_drive',
    name: 'Campus Citrus Drive',
    brand: 'Urban Pulse',
    price: 899,
    stock: 24,
    gender: 'men',
    season: 'summer',
    fragranceFamily: 'fresh citrus',
    notes: ['citrus', 'aquatic', 'woody'],
    topNotes: ['citrus', 'aquatic'],
    middleNotes: ['woody'],
    baseNotes: ['musk'],
    tags: ['fresh', 'clean', 'classic'],
    occasion: 'university',
    time: 'day',
    intensity: 'light',
    description: 'Fresh citrus and aquatic accord built for hot days, campus runs, and casual daytime wear.',
  },
  {
    id: 'ai_test_oud_formal_reserve',
    name: 'Oud Formal Reserve',
    brand: 'Majlis Edition',
    price: 1890,
    stock: 9,
    gender: 'men',
    season: 'winter',
    fragranceFamily: 'oud woody',
    notes: ['oud', 'amber', 'leather', 'spicy'],
    topNotes: ['spicy'],
    middleNotes: ['oud', 'amber'],
    baseNotes: ['leather', 'woody'],
    tags: ['bold', 'smoky', 'warm'],
    occasion: 'formal',
    time: 'night',
    intensity: 'strong',
    description: 'Dense oud and leather composition suited for formal events and cold night weather.',
  },
  {
    id: 'ai_test_rose_day_silk',
    name: 'Rose Day Silk',
    brand: 'Bloom Ritual',
    price: 1120,
    stock: 14,
    gender: 'women',
    season: 'spring',
    fragranceFamily: 'floral musk',
    notes: ['rose', 'floral', 'musk', 'fruity'],
    topNotes: ['fruity'],
    middleNotes: ['rose', 'floral'],
    baseNotes: ['musk'],
    tags: ['clean', 'elegant', 'fresh'],
    occasion: 'daily',
    time: 'all_day',
    intensity: 'light',
    description: 'Airy rose floral scent with a clean musky base for daily spring wear.',
  },
  {
    id: 'ai_test_musk_office_blend',
    name: 'Musk Office Blend',
    brand: 'Minimal Code',
    price: 980,
    stock: 30,
    gender: 'unisex',
    season: 'all_seasons',
    fragranceFamily: 'clean musk',
    notes: ['musk', 'woody', 'citrus'],
    topNotes: ['citrus'],
    middleNotes: ['woody'],
    baseNotes: ['musk'],
    tags: ['clean', 'musky', 'classic'],
    occasion: 'office',
    time: 'day',
    intensity: 'medium',
    description: 'Balanced musk and woods for office use, clean meetings, and all-season reliability.',
  },
  {
    id: 'ai_test_spiced_date_night',
    name: 'Spiced Date Night',
    brand: 'Velvet Hour',
    price: 1560,
    stock: 11,
    gender: 'unisex',
    season: 'autumn',
    fragranceFamily: 'spicy amber',
    notes: ['spicy', 'amber', 'vanilla', 'leather'],
    topNotes: ['spicy'],
    middleNotes: ['amber'],
    baseNotes: ['vanilla', 'leather'],
    tags: ['warm', 'bold', 'sweet'],
    occasion: 'date',
    time: 'night',
    intensity: 'strong',
    description: 'Warm spicy amber scent with vanilla and leather depth for date nights and cooler weather.',
  },
  {
    id: 'ai_test_aqua_casual_breeze',
    name: 'Aqua Casual Breeze',
    brand: 'Blue District',
    price: 760,
    stock: 28,
    gender: 'unisex',
    season: 'summer',
    fragranceFamily: 'aquatic fresh',
    notes: ['aquatic', 'citrus', 'musk'],
    topNotes: ['aquatic', 'citrus'],
    middleNotes: ['floral'],
    baseNotes: ['musk'],
    tags: ['fresh', 'clean'],
    occasion: 'casual',
    time: 'day',
    intensity: 'light',
    description: 'Simple aquatic freshness for relaxed summer outings and daytime casual use.',
  },
  {
    id: 'ai_test_powder_velvet',
    name: 'Powder Velvet',
    brand: 'Soft Atelier',
    price: 1280,
    stock: 13,
    gender: 'women',
    season: 'winter',
    fragranceFamily: 'powdery floral',
    notes: ['powdery', 'vanilla', 'rose', 'musk'],
    topNotes: ['powdery'],
    middleNotes: ['rose', 'floral'],
    baseNotes: ['vanilla', 'musk'],
    tags: ['powdery', 'elegant', 'classic'],
    occasion: 'formal',
    time: 'night',
    intensity: 'medium',
    description: 'Elegant powdery floral style with vanilla warmth for formal winter evenings.',
  },
  {
    id: 'ai_test_woody_study_room',
    name: 'Woody Study Room',
    brand: 'Library House',
    price: 940,
    stock: 20,
    gender: 'men',
    season: 'autumn',
    fragranceFamily: 'woody spicy',
    notes: ['woody', 'citrus', 'spicy', 'musk'],
    topNotes: ['citrus'],
    middleNotes: ['spicy', 'woody'],
    baseNotes: ['musk'],
    tags: ['classic', 'clean'],
    occasion: 'university',
    time: 'all_day',
    intensity: 'medium',
    description: 'Structured woody scent for study sessions, classes, and long all-day wear.',
  },
  {
    id: 'ai_test_fruity_sunset_glow',
    name: 'Fruity Sunset Glow',
    brand: 'Aura Pop',
    price: 1050,
    stock: 16,
    gender: 'women',
    season: 'summer',
    fragranceFamily: 'fruity floral',
    notes: ['fruity', 'floral', 'amber', 'musk'],
    topNotes: ['fruity', 'citrus'],
    middleNotes: ['floral', 'rose'],
    baseNotes: ['amber', 'musk'],
    tags: ['sweet', 'fresh', 'elegant'],
    occasion: 'evening',
    time: 'night',
    intensity: 'medium',
    description: 'Bright fruity floral opening with amber warmth for summer evenings and social outings.',
  },
];

function buildGeneratedProducts() {
  const names = [
    'Cedar Class',
    'Vanilla Study',
    'Midnight Oud',
    'Aqua Lecture',
    'Rose Satin',
    'Amber Code',
    'Citrus Commute',
    'Velvet Spice',
    'Musk Routine',
    'Fresh Pulse',
    'Woody Harbor',
    'Night Signal',
    'Floral Whisper',
    'Blue Diary',
    'Golden Resin',
    'Urban Breeze',
    'Soft Powder',
    'Dark Ember',
    'Clean Linen',
    'Silver Leaf',
    'Date Harmony',
    'Office Focus',
    'Dawn Splash',
    'Noir Cedar',
    'Sweet Drift',
    'Marine Echo',
    'Classic Trail',
    'Warm Lab',
    'Quiet Bloom',
    'Bold Route',
  ];

  const genders = ['men', 'women', 'unisex'];
  const seasons = ['summer', 'winter', 'spring', 'autumn', 'all_seasons'];
  const occasions = ['daily', 'formal', 'evening', 'casual', 'office', 'date', 'university'];
  const times = ['day', 'night', 'all_day'];
  const intensities = ['light', 'medium', 'strong'];
  const families = ['fresh citrus', 'woody spicy', 'amber gourmand', 'floral musk', 'aquatic fresh'];
  const noteSets = [
    ['citrus', 'aquatic', 'musk'],
    ['vanilla', 'amber', 'musk'],
    ['oud', 'leather', 'spicy'],
    ['rose', 'floral', 'musk'],
    ['woody', 'citrus', 'amber'],
    ['fruity', 'floral', 'vanilla'],
    ['powdery', 'musk', 'woody'],
    ['spicy', 'amber', 'vanilla'],
    ['fresh', 'citrus', 'woody'],
    ['musky', 'clean', 'aquatic'],
  ];
  const tagSets = [
    ['fresh', 'clean'],
    ['warm', 'sweet'],
    ['bold', 'smoky'],
    ['elegant', 'classic'],
    ['office', 'clean'],
    ['date', 'warm'],
    ['daily', 'light'],
    ['formal', 'strong'],
    ['university', 'casual'],
    ['musky', 'soft'],
  ];

  const generated = [];
  for (let i = 0; i < 30; i += 1) {
    const index = i + 1;
    const notes = noteSets[i % noteSets.length];
    const top = [notes[0]];
    const middle = [notes[1]];
    const base = [notes[2]];
    const title = `${names[i]} ${String(index).padStart(2, '0')}`;
    generated.push({
      id: `ai_test_pack_${String(index).padStart(2, '0')}`,
      name: title,
      brand: `Batch Lab ${((i % 5) + 1)}`,
      price: 650 + (i * 55),
      stock: (i % 9 === 0) ? 0 : 6 + (i % 18),
      gender: genders[i % genders.length],
      season: seasons[i % seasons.length],
      fragranceFamily: families[i % families.length],
      notes,
      topNotes: top,
      middleNotes: middle,
      baseNotes: base,
      tags: tagSets[i % tagSets.length],
      occasion: occasions[i % occasions.length],
      time: times[i % times.length],
      intensity: intensities[i % intensities.length],
      description: `${title} is a seeded AI test perfume for recommendation, follow-up, and comparison flows.`,
    });
  }
  return generated;
}

const generatedProducts = buildGeneratedProducts();
const allProducts = [...products, ...generatedProducts];

async function seedProducts() {
  const batch = db.batch();

  allProducts.forEach((product, index) => {
    const createdAt = new Date(baseDate.getTime() + index * 60000);
    const ref = db.collection('products').doc(product.id);

    batch.set(ref, {
      name: product.name,
      nameLower: product.name.toLowerCase(),
      searchPrefixes: buildSearchPrefixes(product.name),
      brand: product.brand,
      price: product.price,
      stock: product.stock,
      gender: product.gender,
      season: product.season,
      fragranceFamily: product.fragranceFamily,
      fragranceFamilyKey: normalizeQueryKey(product.fragranceFamily),
      notes: product.notes,
      imageUrls: [imageUrl(product.name)],
      description: product.description,
      categoryName: 'Perfumes',
      categoryKey: normalizeQueryKey('Perfumes'),
      createdAt: Timestamp.fromDate(createdAt),
      updatedAt: Timestamp.now(),
      isActive: true,
      saleActive: false,
      occasion: product.occasion,
      time: product.time,
      intensity: product.intensity,
      topNotes: product.topNotes,
      middleNotes: product.middleNotes,
      baseNotes: product.baseNotes,
      tags: product.tags,
      pyramidDescription: `Top: ${product.topNotes.join(', ')}. Middle: ${product.middleNotes.join(', ')}. Base: ${product.baseNotes.join(', ')}.`,
    }, { merge: true });
  });

  await batch.commit();
  console.log(`Seeded ${allProducts.length} AI test products into project ${serviceAccount.project_id}.`);
  for (const product of allProducts) {
    console.log(`${product.id} -> ${product.name}`);
  }
}

seedProducts().catch((error) => {
  console.error('Failed to seed AI test products.');
  console.error(error);
  process.exitCode = 1;
});
