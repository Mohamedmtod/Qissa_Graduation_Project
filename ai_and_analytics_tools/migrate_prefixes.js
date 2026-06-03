// tools/migrate_prefixes.js
// Run: node tools/migrate_prefixes.js
// Requires: firebase-admin SDK configured with your project credentials
//
// This script adds `searchPrefixes` and `nameLower` to all existing
// product documents. It batches in groups of 500 (Firestore max).

const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

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

    const words = cleaned.split(' ').filter(w => w.length >= 2 && !STOP_WORDS.has(w));

    const prefixes = new Set();
    for (const word of words) {
        for (let i = 2; i <= word.length; i++) {
            prefixes.add(word.substring(0, i));
        }
    }

    return [...prefixes];
}

async function migrate() {
    const snapshot = await db.collection('products').get();
    const docs = snapshot.docs;
    console.log(`Total products: ${docs.length}`);

    for (let i = 0; i < docs.length; i += 500) {
        const batch = db.batch();
        const chunk = docs.slice(i, i + 500);

        chunk.forEach(doc => {
            const name = doc.data().name || '';
            batch.update(doc.ref, {
                nameLower: name.toLowerCase(),
                searchPrefixes: buildSearchPrefixes(name),
            });
        });

        await batch.commit();
        console.log(`Migrated ${Math.min(i + 500, docs.length)} / ${docs.length}`);
    }

    console.log('✅ Migration complete!');
}

migrate().catch(console.error);
