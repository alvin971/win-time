# Audit Win Time Pro + Client — Plan d'amélioration UX & features

**Date** : 2026-05-05
**État de départ** : commit `3061fc8` — pipeline cross-app fonctionnel, navigation cassée, Menu CRUD absent, plusieurs features standards manquantes.

---

## Synthèse audit

### Win Time Pro
- ✅ Login + Dashboard temps réel + Mon Restaurant CRUD (4 pages)
- ❌ Navigator standard (pas go_router) → `pushReplacement` chain → back button Android quitte l'app brutalement
- ❌ Boutons "Mot de passe oublié" et "S'inscrire" inactifs (`onPressed: () {}`)
- ❌ **Menu CRUD totalement absent** (entity ProductEntity prête + 0 UI)
- ❌ **Historique commandes absent** (uniquement orders actives via stream realtime)
- ❌ **Statistiques absentes** (StatisticsEntity 200L prête + 0 UI)
- ❌ Profil utilisateur, paramètres, notifications, équipe → tous absents

### Win Time Client
- ✅ go_router avec ShellRoute (Restaurants/Orders/Profil) + 5 pages routes
- ❌ Back button manquant : RestaurantDetailPage, CheckoutPage, OrderTrackingPage (pas de `leading: BackButton()`)
- ❌ Pas de search bar
- ❌ Pas de filtres (cuisine, prix, distance, ouvert maintenant)
- ❌ Pas de cancel order, ni rating post-commande
- ❌ Profil quasi-vide (juste email + logout)
- ❌ Pas de badge cart sur bottom nav
- ⚠️ 8 pages legacy orphelines dans `lib/pages/` polluent le repo

---

## Plan d'exécution (3 vagues)

### ▶ Vague 1 — Navigation & UX bloquants (P0)

**Pro** :
1. `dashboard_page.dart` : ajouter `PopScope` avec confirm dialog "Quitter Win Time Pro ?" (évite quitter par accident)
2. `login_page.dart` : câbler "S'inscrire" → push RegisterPage, "Mot de passe oublié" → bottom sheet basique avec input email + supabase.auth.resetPasswordForEmail()
3. `my_restaurant_page.dart` : déjà a une AppBar avec back auto (push), juste vérifier

**Client** :
4. `restaurant_detail_page.dart` : SliverAppBar — ajouter `leading: BackButton()` (à cause du auto-leading non-déclenché par CustomScrollView)
5. `checkout_page.dart` : AppBar — ajouter `leading: BackButton()`
6. `order_tracking_page.dart` : AppBar — ajouter `leading: BackButton()` qui pop vers /home/orders au lieu de stack

**Effort** : ~45 min

### ▶ Vague 2 — Pro Menu CRUD (P0 majeur)

Le Pro N'A PAS de moyen de gérer son menu dans l'app actuelle. C'est inutilisable pour un commerçant en pratique.

**À créer** :
7. `lib/features/menu/presentation/pages/menu_page.dart` (~400 lignes)
   - List sectionnée par catégorie
   - FAB pour ajouter
   - Tap catégorie → édition / supprimer
   - Tap produit → ProductFormPage
8. `lib/features/menu/presentation/pages/product_form_page.dart` (~500 lignes)
   - Mode CREATE/EDIT auto
   - Form : nom, description, prix, catégorie, image, allergens, labels, isAvailable, prep time
   - Photo via image_picker + compression + upload Supabase Storage `restaurant-photos/{ownerId}/products/{productId}.jpg`
9. `lib/features/menu/presentation/widgets/category_edit_sheet.dart` (~150 lignes)
   - Bottom sheet : nom + description + display_order + delete
10. `lib/features/menu/data/datasources/supabase_menu_datasource.dart`
    - Ajouter `createCategory`, `updateCategory`, `deleteCategory`, `createProduct`, `updateProduct`, `deleteProduct`, `setProductAvailable`
11. `dashboard_page.dart` : ajouter "Mon Menu" dans le PopupMenuButton kebab

**Effort** : ~3h

### ▶ Vague 3 — UX Client P1 + Pro Historique (P1)

**Pro** :
12. `lib/features/orders/presentation/pages/order_history_page.dart` (~250 lignes)
    - Liste orders status completed/cancelled/rejected, filtre date
    - Pagination simple (limit 50)

**Client** :
13. `restaurants_list_page.dart` : ajouter SearchBar dans AppBar (filtre sur name + cuisine + city côté Dart, dataset déjà chargé)
14. `restaurants_list_page.dart` : ajouter ChipsRow filters au-dessus de la liste (cuisine type chips multi-select + price range + "ouvert maintenant" toggle)
15. `app_router.dart` : bottom nav tab "Commandes" → afficher badge avec count d'orders actives (StreamBuilder count)
16. `restaurant_detail_page.dart` : afficher le FAB cart de manière plus visible + sticky, badge avec count
17. `order_tracking_page.dart` : si status==pending, ajouter un bouton "Annuler" qui appelle `SupabaseOrdersDataSource.cancelOrder()`
18. `order_tracking_page.dart` : si status==completed, afficher une modale "Donner une note" → 5 stars + commentaire → UPDATE rating/review
19. `app_router.dart` `_ProfileTab` → migrer vers vraie page `lib/features/profile/presentation/pages/profile_page.dart` avec form (nom + photo) + bouton sign-out

**Effort** : ~3h

### ▶ Vague 4 — Polish (P2, défilé pour session future)

- Photos produits dans le menu (CachedNetworkImage avec fallback)
- Notifications push setup (FCM)
- Skeleton loading
- Cleanup `lib/pages/` legacy
- Animations transitions
- Mode hors ligne
- Print/Export ticket
- Gestion équipe (Pro)
- Programme fidélité (Client)

---

## Files à toucher (récap top-15)

### Pro
1. `win_time_pro_mobilapp/lib/features/orders/presentation/pages/dashboard_page.dart` (PopScope + lien Menu)
2. `win_time_pro_mobilapp/lib/features/auth/presentation/pages/login_page.dart` (boutons inactifs)
3. `win_time_pro_mobilapp/lib/features/menu/presentation/pages/menu_page.dart` (NEW)
4. `win_time_pro_mobilapp/lib/features/menu/presentation/pages/product_form_page.dart` (NEW)
5. `win_time_pro_mobilapp/lib/features/menu/presentation/widgets/category_edit_sheet.dart` (NEW)
6. `win_time_pro_mobilapp/lib/features/menu/data/datasources/supabase_menu_datasource.dart` (NEW)
7. `win_time_pro_mobilapp/lib/features/orders/presentation/pages/order_history_page.dart` (NEW)

### Client
8. `win_time_mobilapp/lib/features/restaurants/presentation/pages/restaurants_list_page.dart` (search + filters)
9. `win_time_mobilapp/lib/features/restaurants/presentation/pages/restaurant_detail_page.dart` (back button + cart visible)
10. `win_time_mobilapp/lib/features/checkout/presentation/pages/checkout_page.dart` (back button)
11. `win_time_mobilapp/lib/features/orders/presentation/pages/order_tracking_page.dart` (back + cancel + rating)
12. `win_time_mobilapp/lib/features/profile/presentation/pages/profile_page.dart` (NEW)
13. `win_time_mobilapp/lib/core/router/app_router.dart` (badge nav + profile tab → real page)

### Migration DB (Postgres)
14. `migrations/20260505_040_user_favorites.sql` (NEW — table favorites pour Wave 4 défilée)

---

## Stratégie d'exécution

1. **Vague 1** → 1 commit "fix(nav): back buttons + login active links + PopScope dashboard"
2. **Vague 2** → 1 commit "feat(pro/menu): CRUD complet menu (catégories + produits + photos)"
3. **Vague 3** → 1 commit "feat(client/ux): search + filters + back nav + cancel + rating + profile + badge"
4. Push cumulatif → 5 workflows CI (Pro+Client iOS + Cloudflare + Lint)
5. ~30-50 min de CI total

**Effort code total estimé** : 6-7h
**Pas de blocker techniques** : tout est additif, pas de refactoring DB. Architecture en place.

---

## Verification post-déploiement

Une fois TestFlight processed :
1. Pro : login Manager → tap Mon Menu (kebab) → modifier produit / créer catégorie / supprimer / réorganiser
2. Pro : login Manager → tap Historique → voir orders completed
3. Pro : login Manager → tap "Mot de passe oublié" → entrer email → snackbar succès
4. Client : login → search "italien" → 1 résultat (Trattoria) ; toggle "ouvert maintenant" → filtre
5. Client : passer commande → tracking → tap "Annuler" si pending
6. Client : commande completed (à simuler via Pro qui marque completed) → modale "Note ce restaurant" 5 stars
7. Client : profil → modifier nom → save → vérif Postgres
8. Client : bottom nav "Commandes" doit afficher un badge avec le nombre d'actives
9. Client : back button iOS swipe-from-left fonctionne sur RestaurantDetail / Checkout / Tracking
10. Pro : back Android sur Dashboard → dialog "Quitter Win Time Pro ?" → choix
