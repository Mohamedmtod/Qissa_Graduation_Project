const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'demo-perfume-admin';
const RULES_PATH = path.resolve(__dirname, '..', 'rules', 'firestore.rules');

let testEnv;

async function seedFirestore(dataSeeder) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await dataSeeder(context.firestore());
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.afterEach(async () => {
  await testEnv.clearFirestore();
});

test('regular user cannot update product stock', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({role: 'user'});
    await db.collection('products').doc('product-1').set({
      name: 'Rose Noir',
      stock: 4,
      price: 120,
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('products').doc('product-1').update({stock: 7}),
  );
});

test('regular user cannot write banner or category records', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({role: 'user'});
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('banner').doc('banner-1').set({title: 'Hero Banner'}),
  );
  await assertFails(
    db.collection('categories').doc('cat-1').set({name: 'Oud'}),
  );
  await assertFails(
    db.collection('config').doc('business_info').set({storeName: 'Qissa'}),
  );
  await assertFails(
    db.collection('product_public_stats').doc('product-1').set({
      productId: 'product-1',
      soldQty30d: 5,
    }),
  );
});

test('public business info and product stats are readable only', async () => {
  await seedFirestore(async (db) => {
    await db.collection('config').doc('business_info').set({
      storeName: 'Qissa',
      isPublished: true,
    });
    await db.collection('product_public_stats').doc('product-1').set({
      productId: 'product-1',
      soldQty30d: 5,
    });
  });

  const publicDb = testEnv.unauthenticatedContext().firestore();

  await assertSucceeds(
    publicDb.collection('config').doc('business_info').get(),
  );
  await assertSucceeds(
    publicDb.collection('product_public_stats').doc('product-1').get(),
  );
  await assertFails(
    publicDb.collection('config').doc('business_info').set({
      storeName: 'Public edit',
    }),
  );
  await assertFails(
    publicDb.collection('product_public_stats').doc('product-1').set({
      soldQty30d: 99,
    }),
  );
});

test('regular user cannot update orders', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({role: 'user'});
    await db.collection('orders').doc('order-1').set({
      userId: 'user-1',
      status: 'pending',
      total: 180,
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('orders').doc('order-1').update({status: 'shipped'}),
  );
});

test('admin can perform allowed admin writes', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('admin-1').set({role: 'admin'});
    await db.collection('products').doc('product-1').set({
      name: 'Rose Noir',
      stock: 4,
      price: 120,
      featured: false,
    });
  });

  const db = testEnv.authenticatedContext('admin-1').firestore();

  await assertSucceeds(
    db.collection('banner').doc('banner-1').set({title: 'Hero Banner'}),
  );
  await assertSucceeds(
    db.collection('categories').doc('cat-1').set({name: 'Oud'}),
  );
  await assertSucceeds(
    db.collection('config').doc('business_info').set({storeName: 'Qissa'}),
  );
  await assertSucceeds(
    db.collection('product_public_stats').doc('product-1').set({
      productId: 'product-1',
      soldQty30d: 5,
    }),
  );
  await assertSucceeds(
    db.collection('products').doc('product-1').update({featured: true}),
  );
  await assertFails(
    db.collection('products').doc('product-1').update({stock: 12}),
  );
});

test('admin can update product staff taste fields without changing stock', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('admin-1').set({role: 'admin'});
    await db.collection('products').doc('product-1').set({
      name: 'Rose Noir',
      stock: 4,
      price: 120,
    });
  });

  const db = testEnv.authenticatedContext('admin-1').firestore();

  await assertSucceeds(
    db.collection('products').doc('product-1').update({
      staffTagScores: {
        office: 3,
        clean: 2,
        safe_blind_buy: 2,
      },
      staffWarnings: ['not_for_hot_weather'],
      staffSalesNotes: {
        ar: 'مناسب للشغل والاستخدام اليومي.',
        en: 'Good for office and daily use.',
      },
      similarFamousDna: ['sauvage_like'],
      staffIntelligenceStatus: 'reviewed',
      reviewNeeded: false,
      staffConfidence: 2,
      staffDataCoverage: 1,
      staffTaxonomyVersion: 1,
      staffUpdatedBy: 'admin-1',
      staffUpdatedAt: new Date(),
      staffReviewCount: 1,
    }),
  );
});

test('regular user cannot update product staff taste fields', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({role: 'user'});
    await db.collection('products').doc('product-1').set({
      name: 'Rose Noir',
      stock: 4,
      price: 120,
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('products').doc('product-1').update({
      staffTagScores: {office: 3},
      staffIntelligenceStatus: 'trusted',
    }),
  );
});

test('user can read and update only their own allowed user document fields', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
      firstName: 'Qissa',
    });
    await db.collection('users').doc('user-2').set({
      uid: 'user-2',
      role: 'user',
      firstName: 'Other',
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  const ownDoc = db.collection('users').doc('user-1');
  const otherDoc = db.collection('users').doc('user-2');

  await assertSucceeds(ownDoc.get());
  await assertSucceeds(ownDoc.update({firstName: 'Updated Name'}));
  await assertFails(ownDoc.update({role: 'admin'}));
  await assertFails(otherDoc.get());

  const snapshot = await ownDoc.get();
  assert.equal(snapshot.data().firstName, 'Updated Name');
});

test('signed-in user can create a pending restock request with the unified schema', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
    });
    await db.collection('products').doc('product-1').set({
      name: 'Rose Noir',
      stock: 0,
      price: 120,
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertSucceeds(
    db.collection('restock_requests').doc('user-1_product-1').set({
      id: 'user-1_product-1',
      productId: 'product-1',
      userId: 'user-1',
      contactMethod: 'email',
      contactValue: 'user@test.com',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
      notifiedAt: null,
    }),
  );
});

test('signed-in user can create a pending restock request without notifiedAt', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
    });
    await db.collection('products').doc('product-1').set({
      name: 'Rose Noir',
      stock: 0,
      price: 120,
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertSucceeds(
    db.collection('restock_requests').doc('user-1_product-1').set({
      id: 'user-1_product-1',
      productId: 'product-1',
      userId: 'user-1',
      contactMethod: 'email',
      contactValue: 'user@test.com',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );
});

test('signed-in user cannot update or delete a restock request', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
    });
    await db.collection('restock_requests').doc('user-1_product-1').set({
      id: 'user-1_product-1',
      productId: 'product-1',
      userId: 'user-1',
      contactMethod: 'email',
      contactValue: 'user@test.com',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
      notifiedAt: null,
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('restock_requests').doc('user-1_product-1').update({
      status: 'notified',
    }),
  );
  await assertFails(
    db.collection('restock_requests').doc('user-1_product-1').delete(),
  );
});

test('signed-in user cannot create malformed restock request documents', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('restock_requests').doc('user-1_product-1').set({
      id: 'wrong-id',
      productId: 'product-1',
      userId: 'user-1',
      contactMethod: 'email',
      contactValue: 'user@test.com',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
      notifiedAt: null,
    }),
  );

  await assertFails(
    db.collection('restock_requests').doc('user-1_product-1').set({
      id: 'user-1_product-1',
      productId: 'product-1',
      userId: 'user-1',
      contactMethod: 'email',
      contactValue: 'user@test.com',
      status: 'notified',
      createdAt: new Date(),
      updatedAt: new Date(),
      notifiedAt: null,
    }),
  );
});

test('signed-in user cannot create restock request for missing product', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('restock_requests').doc('user-1_missing-product').set({
      id: 'user-1_missing-product',
      productId: 'missing-product',
      userId: 'user-1',
      contactMethod: 'email',
      contactValue: 'user@test.com',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );
});

test('regular user can create own account deletion request only', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
      email: 'user@test.com',
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertSucceeds(
    db.collection('account_deletion_requests').doc('user-1').set({
      userId: 'user-1',
      email: 'user@test.com',
      reason: '',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );
  await assertFails(
    db.collection('account_deletion_requests').doc('user-2').set({
      userId: 'user-2',
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );
});

test('regular user cannot poison perfume knowledge cache', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('perfume_knowledge').doc('fake-profile').set({
      displayName: 'Fake Perfume',
      brand: 'Fake',
      aliases: [],
      searchKeys: ['fake'],
      accords: [],
      topNotes: [],
      middleNotes: [],
      baseNotes: [],
      fragranceFamily: '',
      extractionMethod: 'model',
      lookupConfidence: 0.9,
      status: 'needsReview',
      usageCount: 0,
      createdAt: new Date(),
      updatedAt: new Date(),
      lastUsedAt: new Date(),
    }),
  );
});

test('signed-in user can create sanitized conversion_notify_requested AI telemetry only', async () => {
  await seedFirestore(async (db) => {
    await db.collection('users').doc('user-1').set({
      uid: 'user-1',
      role: 'user',
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertSucceeds(
    db.collection('ai_chat_events').doc('event-1').set({
      eventType: 'conversion_notify_requested',
      userId: 'user-1',
      sessionId: 'session-1',
      metadata: {
        productId: 'product-1',
        hasUserId: true,
      },
      createdAt: new Date(),
    }),
  );

  await assertFails(
    db.collection('ai_chat_events').doc('event-2').set({
      eventType: 'conversion_notify_requested',
      userId: 'user-1',
      sessionId: 'session-1',
      metadata: {
        productId: 'product-1',
        hasUserId: true,
        message: 'raw user message must not be stored in telemetry',
      },
      createdAt: new Date(),
    }),
  );
});

test('ai chat session owner can complete a legacy-shaped session', async () => {
  const startedAt = new Date('2026-04-29T10:00:00.000Z');

  await seedFirestore(async (db) => {
    await db.collection('ai_chat_sessions').doc('session-1').set({
      _schemaVersion: 1,
      id: 'session-1',
      userId: 'user-1',
      language: 'en',
      status: 'active',
      startedAt,
      endedAt: null,
      messageCount: 0,
      finalRecommendationMessageId: null,
      legacyField: 'kept-from-older-schema',
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertSucceeds(
    db.collection('ai_chat_sessions').doc('session-1').set(
      {
        _schemaVersion: 1,
        status: 'ended',
        endedAt: new Date('2026-04-29T10:05:00.000Z'),
        messageCount: 3,
        finalRecommendationMessageId: 'msg-3',
      },
      {merge: true},
    ),
  );
});

test('unauthenticated users cannot create ai chat sessions', async () => {
  const db = testEnv.unauthenticatedContext().firestore();

  await assertFails(
    db.collection('ai_chat_sessions').doc('session-guest').set({
      _schemaVersion: 1,
      id: 'session-guest',
      userId: 'anonymous',
      language: 'en',
      status: 'active',
      startedAt: new Date('2026-04-29T10:00:00.000Z'),
      endedAt: null,
      messageCount: 0,
      finalRecommendationMessageId: null,
    }),
  );
});

test('ai chat session owner can create a session and append messages', async () => {
  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertSucceeds(
    db.collection('ai_chat_sessions').doc('session-1').set({
      _schemaVersion: 1,
      id: 'session-1',
      userId: 'user-1',
      language: 'en',
      status: 'active',
      startedAt: new Date('2026-04-29T10:00:00.000Z'),
      endedAt: null,
      messageCount: 0,
      finalRecommendationMessageId: null,
    }),
  );

  await assertSucceeds(
    db.collection('ai_chat_messages').doc('session-1_msg-1').set({
      _schemaVersion: 1,
      id: 'msg-1',
      sessionId: 'session-1',
      role: 'user',
      content: 'hello',
      messageType: 'text',
      productIds: [],
      createdAt: new Date('2026-04-29T10:00:01.000Z'),
    }),
  );
});

test('ai chat session cannot be read or written by another user', async () => {
  await seedFirestore(async (db) => {
    await db.collection('ai_chat_sessions').doc('session-1').set({
      _schemaVersion: 1,
      id: 'session-1',
      userId: 'user-1',
      language: 'en',
      status: 'active',
      startedAt: new Date('2026-04-29T10:00:00.000Z'),
      endedAt: null,
      messageCount: 0,
      finalRecommendationMessageId: null,
    });
  });

  const db = testEnv.authenticatedContext('user-2').firestore();

  await assertFails(db.collection('ai_chat_sessions').doc('session-1').get());
  await assertFails(
    db.collection('ai_chat_messages').doc('session-1_msg-2').set({
      _schemaVersion: 1,
      id: 'msg-2',
      sessionId: 'session-1',
      role: 'user',
      content: 'cross user write',
      messageType: 'text',
      productIds: [],
      createdAt: new Date('2026-04-29T10:00:02.000Z'),
    }),
  );
});

test('ai chat session owner cannot change immutable session fields', async () => {
  const startedAt = new Date('2026-04-29T10:00:00.000Z');

  await seedFirestore(async (db) => {
    await db.collection('ai_chat_sessions').doc('session-1').set({
      _schemaVersion: 1,
      id: 'session-1',
      userId: 'user-1',
      language: 'en',
      status: 'active',
      startedAt,
      endedAt: null,
      messageCount: 0,
      finalRecommendationMessageId: null,
    });
  });

  const db = testEnv.authenticatedContext('user-1').firestore();

  await assertFails(
    db.collection('ai_chat_sessions').doc('session-1').set(
      {
        _schemaVersion: 1,
        userId: 'user-2',
        status: 'ended',
        endedAt: new Date('2026-04-29T10:05:00.000Z'),
        messageCount: 3,
      },
      {merge: true},
    ),
  );
});
