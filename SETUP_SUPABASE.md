# Setup Supabase — Win Time

Win Time utilise l'instance **Supabase auto-hostée** déjà active sur le VPS
(`https://supabase.0for0.com`), partagée avec Mentality mais dans un schéma
Postgres dédié `wintime` (isolation logique stricte).

## État actuel (déjà fait)

- ✅ Schéma `wintime` créé (5 tables : `user_profiles`, `restaurants`, `categories`, `products`, `orders`)
- ✅ Indexes (geohash, owner, status×date, etc.) appliqués
- ✅ Triggers `updated_at` automatiques
- ✅ Realtime publication activée pour `orders`/`restaurants`/`products`/`categories`
- ✅ Permissions GRANT pour rôles `anon`/`authenticated`/`service_role`
- ✅ RLS policies strictes sur les 5 tables
- ✅ PostgREST exposant `wintime` (variable `PGRST_DB_SCHEMAS=public,storage,graphql_public,wintime`)
- ✅ Seed initial : 8 users Auth + 8 profils + 4 restaurants Paris + 15 cats + 25 produits

Migrations appliquées :
- `migrations/20260504_010_wintime_schema.sql`
- `migrations/20260504_020_wintime_rls.sql`

---

## 1. Branchement Flutter (Pro + Client)

### pubspec.yaml de chaque app
```yaml
dependencies:
  supabase_flutter: ^2.8.0
```

### Configuration (à mettre dans `lib/core/config/`)
```dart
class WintimeSupabaseConfig {
  static const String url = 'https://supabase.0for0.com';
  // Anon key — RLS protège, OK à embarquer dans le bundle.
  static const String anonKey =
    'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9'
    '.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgIml'
    'hdCI6IDE3NzM5NjE0NTIsICJleHAiOiAyMDg5MzIxNDUyfQ'
    '.zU4lqg55i1aUG-SEIz_SeVCdMI5twUyqK4W1eyVMXYo';
  static const String schema = 'wintime';
}
```

### Init dans `main.dart` des 2 apps
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

await Supabase.initialize(
  url: WintimeSupabaseConfig.url,
  anonKey: WintimeSupabaseConfig.anonKey,
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
  ),
);
```

### Pattern d'usage côté datasource
```dart
final supabase = Supabase.instance.client;

// Lecture (RLS appliquée automatiquement)
final rows = await supabase
  .schema('wintime')
  .from('restaurants')
  .select()
  .eq('is_active', true)
  .eq('is_approved', true);
final restaurants = rows.map(RestaurantModel.fromRow).toList();

// Écriture (RLS exige owner_id == auth.uid())
await supabase
  .schema('wintime')
  .from('restaurants')
  .upsert(RestaurantModel.toRow(myRestaurant));

// Realtime stream (Pro dashboard)
final stream = supabase
  .schema('wintime')
  .from('orders')
  .stream(primaryKey: ['id'])
  .eq('restaurant_id', myRestaurantId);
```

---

## 2. Géoloc côté Client (query par proximité)

Le geohash est calculé automatiquement par `RestaurantModel.toRow()`
(via `Geohash.encode` dans shared_core) au moment du write côté Pro.
Côté Client, pour récupérer les restos dans un rayon donné :

```dart
final position = await LocationService.getCurrentPosition(); // existant
final boxes = Geohash.boundingBoxHashes(
  position.latitude, position.longitude, radiusKm: 5,
);

// Une query Postgres OR-able sur les ranges
final futures = boxes.map((b) => supabase
  .schema('wintime')
  .from('restaurants')
  .select()
  .gte('geohash', b.start)
  .lt('geohash', b.end)
  .eq('is_active', true)
  .eq('is_approved', true));
final results = await Future.wait(futures);
final all = results.expand((r) => r).map(RestaurantModel.fromRow);

// Post-filtre Haversine (élimine les false positives en bord de bbox)
final filtered = all.where((r) =>
  Geohash.distanceMeters(
    position.latitude, position.longitude,
    r.address.latitude, r.address.longitude,
  ) <= 5000,
).toList()
  ..sort((a, b) => /* tri par distance */);
```

---

## 3. Auth — comptes de démo seedés

| Email | Password | Rôle | Owns |
|-------|----------|------|------|
| `owner.demo@wintime.test` | `demo-pass-1234` | restaurantOwner | La Trattoria |
| `manager.demo@wintime.test` | `demo-pass-1234` | restaurantManager | — |
| `staff.demo@wintime.test` | `demo-pass-1234` | restaurantStaff | — |
| `admin.demo@wintime.test` | `demo-pass-1234` | admin | — |
| `demo.customer@wintime.test` | `demo-pass-1234` | client | — |
| `louvre@wintime.test` | `demo-pass-1234` | restaurantOwner | Bistrot du Louvre |
| `sakura@wintime.test` | `demo-pass-1234` | restaurantOwner | Sakura Sushi |
| `etoile@wintime.test` | `demo-pass-1234` | restaurantOwner | Beirut Étoile |

Login depuis Flutter :
```dart
await supabase.auth.signInWithPassword(
  email: 'owner.demo@wintime.test',
  password: 'demo-pass-1234',
);
```

Le `auth.uid()` correspondant sera utilisé dans les RLS policies pour
autoriser les reads/writes.

---

## 4. Réappliquer les migrations (utile si reset/dev)

```bash
docker cp /home/ubuntu/win-time/migrations/20260504_010_wintime_schema.sql supabase-db:/tmp/010.sql
docker cp /home/ubuntu/win-time/migrations/20260504_020_wintime_rls.sql supabase-db:/tmp/020.sql
docker exec supabase-db psql -U postgres -d postgres -f /tmp/010.sql
docker exec supabase-db psql -U postgres -d postgres -f /tmp/020.sql
```

Les migrations sont **idempotentes** (`CREATE TABLE IF NOT EXISTS`,
`DROP POLICY IF EXISTS`, etc.) — peuvent être relancées sans casser.

---

## 5. Re-seeder

```bash
cd /home/ubuntu/win-time/scripts
# .env doit déjà contenir SUPABASE_URL + SUPABASE_SERVICE_ROLE
node seed_supabase.js
# OU
./seed_demo.sh
```

Idempotent : `upsert` partout, peut être relancé sans dupliquer.

---

## 6. Reset complet (DANGER — efface le wintime schema)

```bash
docker exec supabase-db psql -U postgres -d postgres -c "DROP SCHEMA wintime CASCADE;"
# Note: ne supprime PAS les comptes auth.users (seedés via Auth admin).
# Pour les supprimer :
docker exec supabase-db psql -U postgres -d postgres -c \
  "DELETE FROM auth.users WHERE raw_user_meta_data->>'app' = 'wintime';"
```

Puis ré-appliquer les migrations + seed.

---

## 7. Vérification rapide depuis cURL

```bash
ANON='eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgImlhdCI6IDE3NzM5NjE0NTIsICJleHAiOiAyMDg5MzIxNDUyfQ.zU4lqg55i1aUG-SEIz_SeVCdMI5twUyqK4W1eyVMXYo'

# Anon (non authentifié) — RLS retourne 0 rows
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Accept-Profile: wintime" \
  "https://supabase.0for0.com/rest/v1/restaurants?select=name&limit=3"
# → []
```

L'anon ne voit aucun restaurant tant qu'il n'est pas authentifié — c'est
le comportement attendu (RLS exige `auth.uid() IS NOT NULL`).

---

## 8. Sécurité

- **service role key** : stockée dans `scripts/.env` (gitignored). Ne JAMAIS
  l'embarquer dans le bundle Flutter (elle bypass toute RLS).
- **anon key** : OK à embarquer dans le bundle (protégée par RLS).
- **Postgres password** : seul accès via la pool, jamais exposé aux apps.
- **JWT secret** : utilisé uniquement par Auth/PostgREST côté serveur.

Pour révoquer/rotater les keys : régénérer dans Supabase Studio
(`https://supabase.0for0.com/project/...`/Settings/API).

---

## 9. Prochaines étapes côté Flutter

Sessions suivantes (côté code apps, en aucun cas pour la console) :

- **Phase 2.5 — Auth migration**
  - Pro : `DemoAuthRepository` wrap `supabase.auth.signInWithPassword`
  - Client : `login_page` → `signInWithPassword` + bouton "anon" → `signInAnonymously`
- **Phase 4 — Pro UI**
  - Tuer `_buildDemoOrders()` dans `dashboard_page.dart`
  - `FirestoreOrdersDataSource` → `SupabaseOrdersDataSource` (stream realtime sur `orders` filtré par `restaurant_id`)
  - Page "Mon Restaurant" + Menu CRUD
- **Phase 5 — Client UI**
  - Remplace les 3 placeholders de `app_router.dart`
  - `RestaurantsListPage` (geohash query + sort by distance)
  - Détail resto, cart, checkout, tracking realtime
