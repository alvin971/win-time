# WINTIME.md — Référence complète du projet

> Fichier de référence pour toutes les sessions. Lire en premier avant toute tâche.
> Dernière mise à jour : **13 mai 2026 (post-audit Sprint 0/1 — voir `WINTIME_AUDIT_REPORT.md` et `WINTIME_EXECUTION_PLAN.md`)**
>
> Ancienne version (avril 2026) archivée dans le git history — décrivait une
> architecture custom REST `api.wintime.com` + Socket.IO qui n'a jamais été
> construite. Le backend réel est Supabase auto-hosté.

---

## 1. Vue d'ensemble

**Win Time** est une plateforme **Click & Collect** pour restaurants français :

| Composant | Dossier | Rôle |
|-----------|---------|------|
| App client | `win_time_mobilapp/` | Clients : parcourir, commander, payer (Stripe), tracker pickup |
| App restaurateur | `win_time_pro_mobilapp/` | Resto : recevoir/gérer commandes, menu, statistiques |
| Package partagé | `packages/shared_core/` | Entités, enums, erreurs, geohash, validators |
| Migrations DB | `migrations/*.sql` | Schéma + RLS + Storage bucket + amendments 040/050/060/070 |
| Edge Functions | `supabase/functions/` | Stripe webhook, create-payment-intent, stripe-connect-onboard |
| Web légal | `web/legal/` + `web/.well-known/` | Politique de confidentialité, CGV, mentions légales, Universal Links |
| Scripts | `scripts/` | Seed Supabase, ASC tooling, backup R2 |

**Backend** : **self-hosted Supabase** à `https://supabase.0for0.com`, schéma `wintime`. **Pas de custom REST** ; les apps parlent directement à Supabase (Auth, PostgREST, Storage, Realtime). Les Edge Functions ajoutent les surfaces Stripe.

---

## 2. Architecture

```
┌───────────────────────────────┐     ┌──────────────────────────────────┐
│ win_time_mobilapp (Client)    │     │ win_time_pro_mobilapp (Pro)      │
│                               │     │                                  │
│ - Supabase Auth + PostgREST   │     │ - Supabase Auth + PostgREST      │
│ - Supabase Realtime channels  │     │ - Supabase Realtime channels     │
│ - flutter_stripe + Edge Fns   │     │ - Stripe Connect onboard         │
│ - Sentry crash reports        │     │ - Sentry + wakelock_plus         │
│ - geolocator (restaurants)    │     │ - image_picker (menu photos)     │
└──────────────┬────────────────┘     └──────────────┬───────────────────┘
               │                                     │
               │             shared_core             │
               │  (entities/enums/errors/geohash)    │
               └───────────────────┬─────────────────┘
                                   │
              ┌────────────────────▼────────────────────┐
              │  supabase.0for0.com — schéma `wintime`  │
              │  ┌──────────────────────────────────┐   │
              │  │ PostgREST + Auth + Storage +     │   │
              │  │ Realtime + Edge Functions (Deno) │   │
              │  └──────────────────────────────────┘   │
              │  Tables : user_profiles, restaurants,   │
              │  categories, products, orders,          │
              │  restaurant_members, order_number_seq,  │
              │  invoice_number_seq                     │
              └─────────────────────────────────────────┘
                                   │
                          ┌────────▼────────┐
                          │ Stripe (Connect) │ — paiement + payout
                          └─────────────────┘
```

**Pas de bridge direct Client↔Pro**. Coordination via :
- INSERT côté Client → trigger serveur valide montants/taxes → status pending
- Pro souscrit au stream realtime `wintime.orders WHERE restaurant_id = mien`
- Pro UPDATE status (state-machine trigger valide la transition + stamp serveur)
- Client re-render via realtime channel

---

## 3. Flux commande (mis à jour, server-side)

```
[CLIENT] Cart → Checkout
   ↓ INSERT INTO wintime.orders (items, restaurant_id, customer_info,
                                  pickup_at, payment_method)
   ↓ trigger orders_validate_amounts :
       - recompute subtotal/tax/total en cents depuis wintime.products
       - rejette si client diverge > 1 cent
   ↓ trigger orders_fill_order_number :
       - alloue WT-2026-000123 (séquentiel par restaurant/année)
   ↓ trigger orders_gen_pickup_code :
       - 6 chiffres aléatoires
   ↓ status = pending, payment_status = pending
   ↓
[STRIPE, si configuré]
   ↓ Client appelle Edge Function create-payment-intent
   ↓ Edge Function crée PaymentIntent (avec application_fee_amount platform)
   ↓ Client affiche PaymentSheet, Stripe traite
   ↓
[STRIPE → SUPABASE]
   ↓ Webhook payment_intent.succeeded → Edge Function stripe-webhook
   ↓ UPDATE orders SET payment_status='paid', stripe_payment_intent_id, ...
   ↓
[PRO] Realtime channel notifie le restaurant
   ↓ acceptOrder → trigger enforce_order_status_transition → accepted_at = NOW()
   ↓ markReady → status=ready, ready_at = NOW()
   ↓
[CLIENT] PickupCodeBanner affiche le code 6 chiffres + QR
[PRO] Tap "Vérifier code" → PickupCodeVerifySheet
   ↓ saisie correcte → completeOrder → trigger fill_invoice_number
       → FAC-2026-000001 généré (séquentiel L441-9 compliant)
   ↓ status=completed, completed_at = NOW()
```

---

## 4. App client — `win_time_mobilapp/`

### Stack
- Flutter 3.32.x (CI pinning) / Dart >=3.5
- State : `flutter_bloc 8.1.6` + `equatable`
- DI : `get_it 8.0` + `injectable 2.5` (avec stub Dio mort kept-alive — voir audit S2.2.4, à supprimer en Sprint 2 après `build_runner` regen)
- Routing : `go_router 14.6`
- Backend : `supabase_flutter 2.8`
- Réseau secondaire : `dio 5.7` (dead — pour le moment)
- Local : `shared_preferences` + `hive` + `flutter_secure_storage`
- Paiement : `flutter_stripe 11.2` (wiré dans `checkout_page.dart` + `StripePaymentService`)
- Maps : `google_maps_flutter` + `geolocator` + `geocoding`
- Push : `firebase_messaging` (lazy init)
- Realtime : Supabase Realtime channels (le `socket_io_client` est dead)
- Monitoring : `sentry_flutter 8.11`

### Features actuelles

| Feature | Statut |
|---------|--------|
| `auth/` | ✅ Login + register (Supabase Auth direct, BLoC dead) + mot de passe oublié |
| `restaurants/` | ✅ Liste avec géohash + filtres (search, cuisine, prix, ouvert) |
| `menu/` | ✅ Détail resto + ajout au cart |
| `cart/` | ✅ BLoC + auto-persist SharedPreferences (TTL 8h) |
| `checkout/` | ✅ Form + pickup time picker (15min slots) + Stripe PaymentSheet (si key dispo) sinon cash |
| `orders/` | ✅ Realtime tracking + cancel pending + rating completed + pickup code banner |
| `profile/` | 🔧 minimal (email + logout) |

---

## 5. App Pro — `win_time_pro_mobilapp/`

### Stack
- Flutter 3.32.x / Dart >=3.8
- State : `flutter_bloc 8.1.6`
- DI : `ServiceLocator` manuel (pas de GetIt — visibilité explicite)
- Routing : `Navigator` (pas de go_router — connu, voir audit S1.2)
- Backend : `supabase_flutter 2.8`
- Local : `flutter_secure_storage` (JWT) + `hive`
- Charts : `fl_chart` + `syncfusion_flutter_charts`
- Notifications : `firebase_messaging` (lazy)
- Realtime : Supabase Realtime channels
- Crash : `sentry_flutter 8.11` (init via `runWithSentry`)
- Service mode : `wakelock_plus 1.2` (écran reste allumé pendant le service)

### Features actuelles

| Feature | Statut |
|---------|--------|
| `auth/` | ✅ Login Supabase + reset password + demo panel (kDebugMode-only) |
| `dashboard/` | ✅ Realtime stream `wintime.orders` filtré par mon resto |
| `menu/` | ✅ CRUD catégories + produits + photos Storage |
| `profile/` (Mon Restaurant) | ✅ Form complet, photos, business hours editor |
| `orders/history/` | ✅ `OrderHistoryPage` avec filtres + pagination |
| `orders/pickup_verify/` | ✅ `PickupCodeVerifySheet` valide le code 6 chiffres → complete |
| `service_mode/` | ✅ Toggle wakelock dans le kebab dashboard |
| `statistics/` | 🔧 entity seulement — UI en backlog Sprint 2 |

---

## 6. Package partagé — `packages/shared_core/`

Voir la version précédente — inchangé sauf :
- Le `WebSocketService` abstract est devenu un stub vide (audit S11.3.5). Sprint 2 le supprime.
- Les entités/enums restent autoritatives ; les apps qui maintiennent leurs propres copies (Client `OrderEntity`, Pro `OrderEntity` simplifiés) sont en cours d'unification.

---

## 7. Backend — Schéma `wintime` (post-migrations 040/050/060/070)

### Tables

| Table | Colonnes notables (additions post-audit) |
|-------|------------------------------------------|
| `user_profiles` | id, email, role, is_active, **fcm_token** (à ajouter) |
| `restaurants` | + `siret`, `tva_intracommunautaire`, `legal_form`, `rcs_number`, `capital_social_cents`, `stripe_account_id`, `stripe_charges_enabled`, `stripe_payouts_enabled` |
| `categories` | inchangé |
| `products` | + `tax_rate NUMERIC(5,4)` (5.5% / 10% / 20% par CGI 279 m bis) |
| `orders` | + `tax_breakdown JSONB`, `pickup_code`, `stripe_payment_intent_id`, `stripe_charge_id`, `payment_captured_at`, `invoice_number`, `saved_vs_aggregator_cents` (GENERATED) |
| `restaurant_members` | NEW — multi-staff (owner/manager/staff) |
| `order_number_seq` | NEW — séquence par resto/année |
| `invoice_number_seq` | NEW — séquence L441-9 compliant |

### Triggers / fonctions
- `wintime.recompute_and_validate_order_amounts()` — BEFORE INSERT on orders
- `wintime.fill_order_number()` — BEFORE INSERT
- `wintime.gen_pickup_code()` — BEFORE INSERT
- `wintime.enforce_order_status_transition()` — BEFORE UPDATE (state machine)
- `wintime.fill_invoice_number()` — BEFORE UPDATE OF status (alloue FAC-... uniquement quand status passe à 'completed')
- `wintime.anonymize_user(target_uid)` — fonction SECURITY DEFINER pour GDPR Art. 17

### RLS
- Tightened: `products_read` et `categories_read` exigent maintenant `is_active AND is_approved` sur le restaurant (anti-scraping cross-tenant).
- `orders_owner_update` a maintenant un `WITH CHECK` qui interdit la mutation de `restaurant_id` / `customer_id` / `order_number`.
- `restaurant_members` permet aux owners de gérer leur équipe; les managers/staff ne sont pas encore branchés au reste des policies (Sprint 3 — voir ADR-001 dans `WINTIME_EXECUTION_PLAN.md`).

### Edge Functions (Supabase / Deno)
- `stripe-webhook` — vérifie signature Stripe, flippe `payment_status` server-side
- `create-payment-intent` — crée le PaymentIntent avec platform-fee 2.5% + transfer Connect
- `stripe-connect-onboard` — génère l'AccountLink pour l'onboarding KYC restaurateur

---

## 8. Configuration `--dart-define`

| Var | Apps | Quand |
|-----|------|-------|
| `STRIPE_PUBLISHABLE_KEY` | Client | Build release / CI |
| `STRIPE_KEY` | Client (legacy alias) | Build release |
| `GOOGLE_MAPS_KEY` | Client | Build release |
| `SENTRY_DSN_PRO` | Pro | Build release |
| `API_BASE_URL` / `WS_BASE_URL` | Both (legacy, dead) | À supprimer en Sprint 2 |

L'anon key Supabase est hardcodée dans `wintime_supabase_config.dart` (correct — RLS protège).

---

## 9. CI / CD

| Workflow | Cible |
|---|---|
| `ci.yml` | `flutter analyze` + `flutter test` sur les 2 apps |
| `deploy_client.yml` | Cloudflare Pages (web) + **AAB** Android (artefact) |
| `deploy_pro.yml` | Cloudflare Pages (web) + **AAB** Android (artefact) |
| `ios_client.yml` | Fastlane → TestFlight |
| `ios_pro.yml` | Fastlane → TestFlight |
| `asc_check.yml` | Thermomètre ASC manuel |

**Web builds** : `--tree-shake-icons --no-source-maps` (post-audit S12.4).
**Android** : AAB seul, **debug-info** uploadé séparément pour mapping crash.
**iOS** : `cert(force:true)` + `concurrency: ios-signing` (matlab cert dance documenté dans `docs/TESTFLIGHT_LOG.md`).

---

## 10. Documentation à lire

| Fichier | Pour |
|---|---|
| `docs/ONBOARDING.md` | Premier setup en < 2h pour un nouveau dev |
| `docs/RUNBOOK_RESTORE.md` | DR — restaurer depuis backup R2 |
| `docs/UNIVERSAL_LINKS_SETUP.md` | Setup deep-links iOS + Android |
| `docs/TESTFLIGHT_LOG.md` | Logbook de la guerre TestFlight (avril-mai 2026) |
| `WINTIME_AUDIT_REPORT.md` | Audit 360° (1427 lignes, 30 🔴 + 74 🟠 + 37 🟡) |
| `WINTIME_EXECUTION_PLAN.md` | Plan d'exécution post-audit + sign-off |
| `SETUP_SUPABASE.md` | Setup base de données |
| `GUIDE_PACKAGE_PARTAGE.md` | Comment utiliser shared_core |
| `web/legal/*.html` | Mentions légales / CGV / Privacy / Cookies (templates à compléter) |

---

## 11. Gotchas connus (post-audit)

| Problème | Statut |
|----------|--------|
| `socket_io_client` dead post-Supabase realtime | À supprimer Sprint 2 (T38) |
| Dead Dio stub kept-alive dans `injection.dart` | Marqué `dead-api.invalid`. Suppression Sprint 2 (T39) |
| Client app a son propre `OrderEntity` (vs shared_core) | À unifier Sprint 2 |
| Pro `_Order` model parallèle | Renommé `pickupCode`. Migration vers `shared_core.OrderEntity` Sprint 2 |
| `ServiceLocator.currentRestaurantId` global mutable | À migrer vers BLoC Sprint 3 |
| `mobile_scanner` désactivé | Conflit GoogleUtilities — à réactiver pour scanner pickup-code |
| `manager`/`staff` enum values | Backé par `restaurant_members` table — RLS à étendre Sprint 3 (ADR-001) |
| Bundle Android `com.example.win_time` | À renommer avant Play submission (audit T19) |
| Demo accounts | Gatés `kDebugMode` — tree-shakés en release ✓ |

---

## 12. Comptes de démo (dev uniquement)

Mêmes que dans `SETUP_SUPABASE.md` (8 utilisateurs seedés, password `demo-pass-1234`). Les boutons "connexion rapide démo" n'apparaissent qu'en debug build.

---

## 13. Sprint plan

Voir `WINTIME_EXECUTION_PLAN.md` — Sprint 0 fermé (sauf user-actions PAT / domain / keystore / bundle-id / Stripe account / Better Stack monitor), Sprint 1 en cours.
