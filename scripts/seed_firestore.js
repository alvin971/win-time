#!/usr/bin/env node
/**
 * Win Time — Seed script Firestore + Firebase Auth.
 *
 * Lance:
 *   cd scripts/
 *   npm install                # première fois uniquement
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json node seed_firestore.js
 *
 * Le service account est téléchargé depuis :
 *   Firebase Console → Project Settings → Service Accounts → Generate new private key
 * (NE JAMAIS commit ce fichier — voir .gitignore).
 *
 * Comportement :
 *   1. Crée/met à jour les comptes Firebase Auth (UID déterministes depuis data.json)
 *   2. Écrit /users/{uid} avec rôle + profil
 *   3. Écrit /restaurants/{rid} avec geohash calculé depuis lat/lng
 *   4. Écrit les sous-collections /restaurants/{rid}/categories et /products
 *
 * Idempotent : peut être relancé sans dupliquer les données.
 */

'use strict';

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// ─── Geohash (port pure-JS de l'algo Niemeyer 2008) ────────────────────────
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

function encodeGeohash(latitude, longitude, precision = 9) {
  let latRange = [-90.0, 90.0];
  let lngRange = [-180.0, 180.0];
  let hash = '';
  let bits = 0;
  let bit = 0;
  let even = true;

  while (hash.length < precision) {
    let mid;
    if (even) {
      mid = (lngRange[0] + lngRange[1]) / 2;
      if (longitude >= mid) {
        bits = (bits << 1) | 1;
        lngRange[0] = mid;
      } else {
        bits = bits << 1;
        lngRange[1] = mid;
      }
    } else {
      mid = (latRange[0] + latRange[1]) / 2;
      if (latitude >= mid) {
        bits = (bits << 1) | 1;
        latRange[0] = mid;
      } else {
        bits = bits << 1;
        latRange[1] = mid;
      }
    }
    even = !even;

    if (++bit === 5) {
      hash += BASE32[bits];
      bits = 0;
      bit = 0;
    }
  }
  return hash;
}

// ─── Bootstrap ─────────────────────────────────────────────────────────────
function init() {
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error(
      '[seed] ERREUR: env var GOOGLE_APPLICATION_CREDENTIALS non définie.\n' +
        'Télécharger le service account depuis la console Firebase puis exporter:\n' +
        '  export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/service-account.json',
    );
    process.exit(1);
  }
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

// ─── Helpers ───────────────────────────────────────────────────────────────
function loadData() {
  const dataPath = path.join(__dirname, 'seed', 'data.json');
  return JSON.parse(fs.readFileSync(dataPath, 'utf8'));
}

async function upsertAuthUser(user) {
  try {
    await admin.auth().updateUser(user.uid, {
      email: user.email,
      password: user.password,
      displayName: `${user.firstName} ${user.lastName}`,
      phoneNumber: user.phoneNumber,
      emailVerified: true,
    });
    console.log(`[auth] ↻ updated ${user.email} (${user.uid})`);
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      await admin.auth().createUser({
        uid: user.uid,
        email: user.email,
        password: user.password,
        displayName: `${user.firstName} ${user.lastName}`,
        phoneNumber: user.phoneNumber,
        emailVerified: true,
      });
      console.log(`[auth] + created ${user.email} (${user.uid})`);
    } else {
      throw e;
    }
  }
}

async function upsertUserDoc(db, user) {
  const ref = db.collection('users').doc(user.uid);
  const now = admin.firestore.Timestamp.now();
  await ref.set(
    {
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      phoneNumber: user.phoneNumber,
      role: user.role,
      isActive: true,
      isEmailVerified: true,
      createdAt: now,
      lastLoginAt: null,
    },
    { merge: true },
  );
  console.log(`[fs ] /users/${user.uid} ✓`);
}

async function upsertRestaurant(db, r) {
  const geohash = encodeGeohash(r.address.latitude, r.address.longitude, 9);
  const ref = db.collection('restaurants').doc(r.id);
  const now = admin.firestore.Timestamp.now();
  await ref.set(
    {
      ownerId: r.ownerId,
      name: r.name,
      description: r.description,
      slogan: r.slogan,
      cuisineType: r.cuisineType,
      priceRange: r.priceRange,
      priceLevel: priceLevel(r.priceRange),
      address: r.address,
      contactInfo: r.contactInfo,
      socialLinks: null,
      logoUrl: r.logoUrl,
      bannerUrl: r.bannerUrl,
      galleryImages: r.galleryImages || [],
      businessHours: r.businessHours,
      closedDates: [],
      isActive: r.isActive,
      isApproved: r.isApproved,
      acceptingOrders: r.acceptingOrders,
      averagePreparationTime: r.averagePreparationTime,
      maxConcurrentOrders: null,
      rating: r.rating,
      totalReviews: r.totalReviews,
      geohash,
      latitude: r.address.latitude,
      longitude: r.address.longitude,
      menuCategoryIds: [],
      createdAt: now,
      updatedAt: now,
    },
    { merge: true },
  );
  console.log(`[fs ] /restaurants/${r.id} ✓ geohash=${geohash}`);
}

async function upsertMenu(db, restaurantId, menu) {
  const now = admin.firestore.Timestamp.now();
  const restRef = db.collection('restaurants').doc(restaurantId);

  // Categories
  for (const c of menu.categories || []) {
    await restRef.collection('categories').doc(c.id).set(
      {
        restaurantId,
        name: c.name,
        description: c.description ?? null,
        iconUrl: c.iconUrl ?? null,
        displayOrder: c.displayOrder ?? 0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  // Products
  for (const p of menu.products || []) {
    await restRef.collection('products').doc(p.id).set(
      {
        restaurantId,
        categoryId: p.categoryId,
        name: p.name,
        description: p.description,
        price: p.price,
        mainImageUrl: null,
        additionalImages: [],
        ingredients: p.ingredients || [],
        allergens: p.allergens || [],
        nutritionalInfo: null,
        labels: p.labels || [],
        sizes: p.sizes || [],
        options: p.options || [],
        allowedModifications: [],
        isAvailable: true,
        stockQuantity: null,
        estimatedPreparationTime: p.estimatedPreparationTime ?? 15,
        isSeasonal: false,
        availableFrom: null,
        availableUntil: null,
        orderCount: 0,
        rating: null,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  // Denormalize category IDs onto restaurant doc
  await restRef.update({
    menuCategoryIds: (menu.categories || []).map((c) => c.id),
    updatedAt: now,
  });
  console.log(
    `[fs ] /restaurants/${restaurantId}/{categories,products} ✓ ` +
      `(${menu.categories.length} cats, ${menu.products.length} prods)`,
  );
}

function priceLevel(priceRange) {
  switch (priceRange) {
    case 'budget':
      return 1;
    case 'expensive':
      return 3;
    case 'luxury':
      return 4;
    default:
      return 2;
  }
}

// ─── Main ──────────────────────────────────────────────────────────────────
async function main() {
  init();
  const db = admin.firestore();
  const data = loadData();

  console.log('▶ Win Time seed');
  console.log(`  ${data.users.length} users, ${data.restaurants.length} restaurants`);

  // 1. Auth users
  for (const user of data.users) {
    await upsertAuthUser(user);
  }

  // 2. /users/{uid} docs
  for (const user of data.users) {
    await upsertUserDoc(db, user);
  }

  // 3. /restaurants/{rid} docs
  for (const r of data.restaurants) {
    await upsertRestaurant(db, r);
  }

  // 4. Menus
  for (const r of data.restaurants) {
    const menu = data.menus[r.id];
    if (menu) await upsertMenu(db, r.id, menu);
  }

  console.log('✅ Seed terminé.');
}

main().catch((e) => {
  console.error('❌ Seed failed:', e);
  process.exit(1);
});
