#!/usr/bin/env node
/**
 * Win Time — Seed Supabase (auth users + wintime schema).
 *
 * Lance :
 *   cd scripts/
 *   npm install                    # première fois
 *   cp .env.example .env           # puis éditer les valeurs
 *   node seed_supabase.js
 *
 * Variables d'env requises (via .env ou shell) :
 *   SUPABASE_URL          — ex. https://supabase.0for0.com
 *   SUPABASE_SERVICE_ROLE — service role key (BYPASS RLS, ne jamais exposer)
 *
 * Comportement :
 *   1. Crée/met à jour les comptes Supabase Auth (UID = celui dans data.json
 *      pour avoir des FK déterministes vers auth.users)
 *   2. INSERT/UPDATE wintime.user_profiles pour chacun
 *   3. INSERT/UPDATE wintime.restaurants (avec geohash calculé)
 *   4. INSERT/UPDATE wintime.categories puis wintime.products par resto
 *   5. UPDATE wintime.restaurants.menu_category_ids (dénormalisation)
 *
 * Idempotent : peut être relancé sans dupliquer (uses ON CONFLICT … MERGE
 * via upsert).
 */

'use strict';

const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const { createClient } = require('@supabase/supabase-js');
const { v5: uuidv5 } = require('uuid');

// Namespace UUID Win Time (généré aléatoirement, stable, sert de base pour
// les UUID v5 déterministes des entités logiques `demo-rest-trattoria`, etc.)
const WINTIME_NAMESPACE = '0c9e4a3e-8b2f-4c3d-9e1a-5b7d8c2f4e6a';

/// Convertit un identifiant logique humain ("demo-rest-trattoria") en UUID
/// v5 déterministe (toujours le même output pour le même input).
function toUuid(logicalId) {
  return uuidv5(logicalId, WINTIME_NAMESPACE);
}

// ─── Validation env ────────────────────────────────────────────────────────
const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE;
if (!SUPABASE_URL || !SERVICE_ROLE) {
  console.error('[seed] ❌ SUPABASE_URL et SUPABASE_SERVICE_ROLE requis (voir .env.example)');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { autoRefreshToken: false, persistSession: false },
  db: { schema: 'wintime' },
});

// Client séparé pour les opérations auth admin
const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ─── Geohash (pure-JS, port de l'algo Niemeyer 2008) ───────────────────────
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

// ─── Helpers ───────────────────────────────────────────────────────────────
function loadData() {
  return JSON.parse(
    fs.readFileSync(path.join(__dirname, 'seed', 'data.json'), 'utf8'),
  );
}

function priceLevel(priceRange) {
  switch (priceRange) {
    case 'budget': return 1;
    case 'expensive': return 3;
    case 'luxury': return 4;
    default: return 2;
  }
}

// ─── Auth users ────────────────────────────────────────────────────────────
// Cache la liste des users existants (1 fetch global pour éviter N appels).
let _existingUsersCache = null;
async function findExistingUserByEmail(email) {
  if (_existingUsersCache === null) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    if (error) throw error;
    _existingUsersCache = data.users;
  }
  return _existingUsersCache.find((u) => u.email === email) || null;
}

async function upsertAuthUser(user) {
  // 1. Cherche par email
  const existing = await findExistingUserByEmail(user.email);

  if (existing) {
    // Update password + metadata
    const { error } = await supabaseAdmin.auth.admin.updateUserById(existing.id, {
      password: user.password,
      email_confirm: true,
      user_metadata: {
        first_name: user.firstName,
        last_name: user.lastName,
        phone_number: user.phoneNumber,
        app: 'wintime',
      },
    });
    if (error) throw error;
    console.log(`[auth] ↻ ${user.email} (UID ${existing.id})`);
    return existing.id;
  }

  // 2. Sinon création — Supabase génère le UUID
  const { data, error } = await supabaseAdmin.auth.admin.createUser({
    email: user.email,
    password: user.password,
    email_confirm: true,
    user_metadata: {
      first_name: user.firstName,
      last_name: user.lastName,
      phone_number: user.phoneNumber,
      app: 'wintime',
    },
  });
  if (error) throw error;
  console.log(`[auth] + ${user.email} (UID ${data.user.id})`);
  return data.user.id;
}

// ─── user_profiles ─────────────────────────────────────────────────────────
async function upsertUserProfile(user, realUid) {
  const { error } = await supabase
    .from('user_profiles')
    .upsert({
      id: realUid,
      email: user.email,
      first_name: user.firstName,
      last_name: user.lastName,
      phone_number: user.phoneNumber,
      role: user.role,
      is_active: true,
      is_email_verified: true,
    }, { onConflict: 'id' });
  if (error) throw error;
  console.log(`[fs ] user_profiles/${realUid} (${user.role})`);
}

// ─── restaurants ───────────────────────────────────────────────────────────
async function upsertRestaurant(r, ownerUidMap) {
  // Map ownerId logique du JSON → vrai UID Supabase Auth
  const ownerId = ownerUidMap[r.ownerId];
  if (!ownerId) {
    throw new Error(`No auth user mapped for owner "${r.ownerId}" — vérifie data.json`);
  }
  const geohash = encodeGeohash(r.address.latitude, r.address.longitude, 9);
  const restaurantUuid = toUuid(r.id);
  const { error } = await supabase
    .from('restaurants')
    .upsert({
      id: restaurantUuid,
      owner_id: ownerId,
      name: r.name,
      description: r.description,
      slogan: r.slogan,
      cuisine_type: r.cuisineType,
      price_range: r.priceRange,
      price_level: priceLevel(r.priceRange),
      address_street: r.address.street,
      address_city: r.address.city,
      address_postal_code: r.address.postalCode,
      address_country: r.address.country,
      latitude: r.address.latitude,
      longitude: r.address.longitude,
      geohash,
      contact_email: r.contactInfo.email,
      contact_phone: r.contactInfo.phoneNumber,
      contact_website: r.contactInfo.websiteUrl ?? null,
      social_links: null,
      logo_url: r.logoUrl,
      banner_url: r.bannerUrl,
      gallery_images: r.galleryImages || [],
      business_hours: r.businessHours,
      closed_dates: [],
      is_active: r.isActive,
      is_approved: r.isApproved,
      accepting_orders: r.acceptingOrders,
      average_preparation_time: r.averagePreparationTime,
      max_concurrent_orders: null,
      rating: r.rating,
      total_reviews: r.totalReviews,
      menu_category_ids: [],
    }, { onConflict: 'id' });
  if (error) throw error;
  console.log(`[fs ] restaurants/${r.id} (${restaurantUuid}) ✓ geohash=${geohash}`);
}

// ─── categories + products ─────────────────────────────────────────────────
async function upsertMenu(logicalRestaurantId, menu) {
  const restaurantUuid = toUuid(logicalRestaurantId);

  // Categories
  const catRows = (menu.categories || []).map((c) => ({
    id: toUuid(c.id),
    restaurant_id: restaurantUuid,
    name: c.name,
    description: c.description ?? null,
    icon_url: c.iconUrl ?? null,
    display_order: c.displayOrder ?? 0,
    is_active: true,
  }));
  if (catRows.length > 0) {
    const { error } = await supabase.from('categories').upsert(catRows, { onConflict: 'id' });
    if (error) throw error;
  }

  // Products
  const prodRows = (menu.products || []).map((p) => ({
    id: toUuid(p.id),
    restaurant_id: restaurantUuid,
    category_id: toUuid(p.categoryId),
    name: p.name,
    description: p.description,
    price: p.price,
    main_image_url: p.mainImageUrl ?? null,
    additional_images: p.additionalImages ?? [],
    ingredients: p.ingredients || [],
    allergens: p.allergens || [],
    nutritional_info: null,
    labels: p.labels || [],
    sizes: p.sizes || [],
    options: p.options || [],
    allowed_modifications: [],
    is_available: true,
    stock_quantity: null,
    estimated_preparation_time: p.estimatedPreparationTime ?? 15,
    is_seasonal: false,
    available_from: null,
    available_until: null,
    order_count: 0,
    rating: null,
  }));
  if (prodRows.length > 0) {
    const { error } = await supabase.from('products').upsert(prodRows, { onConflict: 'id' });
    if (error) throw error;
  }

  // Dénormalisation menu_category_ids sur le resto
  const { error: errUpd } = await supabase
    .from('restaurants')
    .update({ menu_category_ids: catRows.map((c) => c.id) })
    .eq('id', restaurantUuid);
  if (errUpd) throw errUpd;

  console.log(
    `[fs ] menu/${logicalRestaurantId}: ${catRows.length} cats, ${prodRows.length} prods`,
  );
}

// ─── Main ──────────────────────────────────────────────────────────────────
async function main() {
  console.log('▶ Win Time seed Supabase');
  const data = loadData();
  console.log(`  ${data.users.length} users, ${data.restaurants.length} restaurants`);

  // Map ownerId logique (JSON) → UID Supabase réel (créé/retrouvé via Auth)
  const uidMap = {};

  // 1. Auth users — Supabase Auth génère les UUIDs, on les capture
  for (const user of data.users) {
    const realUid = await upsertAuthUser(user);
    uidMap[user.uid] = realUid;
  }

  // 2. user_profiles (table wintime, FK auth.users via le real UID)
  for (const user of data.users) {
    const realUid = uidMap[user.uid];
    await upsertUserProfile(user, realUid);
  }

  // 3. restaurants
  for (const r of data.restaurants) {
    await upsertRestaurant(r, uidMap);
  }

  // 4. menus
  for (const r of data.restaurants) {
    const menu = data.menus[r.id];
    if (menu) await upsertMenu(r.id, menu);
  }

  console.log('');
  console.log('✅ Seed terminé.');
  console.log('Comptes disponibles (password = demo-pass-1234) :');
  for (const u of data.users) {
    console.log(`   ${u.email.padEnd(35)} → ${u.role}`);
  }
}

main().catch((e) => {
  console.error('❌ Seed failed:', e.message || e);
  if (e.details) console.error('   details:', e.details);
  if (e.hint) console.error('   hint:', e.hint);
  process.exit(1);
});
