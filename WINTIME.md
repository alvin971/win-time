# WINTIME.md — Référence complète du projet

> Fichier de référence pour toutes les sessions. Lire en premier avant toute tâche.
> Dernière mise à jour : avril 2026

---

## 1. Vue d'ensemble

**Win Time** est une plateforme **Click & Collect** pour restaurants, composée de :

| Composant | Dossier | Rôle |
|-----------|---------|------|
| App client | `win_time_mobilapp/` | Clients : parcourir, commander, payer |
| App restaurateur | `win_time_pro_mobilapp/` | Resto : recevoir/gérer commandes, menu, stats |
| Package partagé | `packages/shared_core/` | Entités, enums, erreurs, utils communs |

**Backend** : API REST `https://api.wintime.com/v1` + WebSocket `wss://ws.wintime.com`

---

## 2. Architecture de coopération (loosely coupled)

```
┌─────────────────────────────┐     ┌────────────────────────────────┐
│   win_time_mobilapp          │     │   win_time_pro_mobilapp         │
│   (App Client)               │     │   (App Restaurateur)            │
│                              │     │                                 │
│  flutter_stripe (paiement)   │     │  fl_chart / syncfusion (stats)  │
│  google_maps (géoloc)        │     │  firebase_auth (option)         │
│  geolocator / geocoding      │     │  flutter_secure_storage         │
└─────────────┬────────────────┘     └────────────────┬────────────────┘
              │                                        │
              │         ┌──────────────────┐           │
              └────────►│   shared_core    │◄──────────┘
                        │  (package local) │
                        │                 │
                        │ UserEntity       │
                        │ OrderEntity      │
                        │ UserRole (enum)  │
                        │ OrderStatus      │
                        │ PaymentStatus    │
                        │ PaymentMethod    │
                        │ ApiConstants     │
                        │ StorageKeys      │
                        │ Failure classes  │
                        │ ApiResult<T>     │
                        │ WebSocketService │
                        │ DateFormatter    │
                        │ Validators       │
                        └────────┬─────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Backend commun         │
                    │  REST: api.wintime.com   │
                    │  WS:  ws.wintime.com     │
                    └─────────────────────────┘
```

**Principe fondamental** : les 2 apps ne se parlent **jamais directement**.
Toute coordination passe par le backend :
- Le client passe commande → API REST → backend persiste
- Le backend notifie le restaurant → **WebSocket** → `new_order` event
- Le restaurant accepte → API REST → backend met à jour
- Le backend notifie le client → **WebSocket** → `order_status_updated` event

**Flux commande complet** :
```
Client crée commande
    → POST /orders
    → Backend enregistre (status: pending)
    → WebSocket emit 'new_order' → App restaurant
    → Restaurateur accepte
    → POST /orders/{id}/accept (+ estimatedPreparationTime)
    → Backend met à jour (status: accepted)
    → WebSocket emit 'order_status_updated' → App client
    → Restaurateur marque prête
    → POST /orders/{id}/ready
    → WebSocket emit 'order_ready' → App client (notification push)
    → Client récupère → POST /orders/{id}/complete
```

---

## 3. App client — `win_time_mobilapp/`

### Stack
- Flutter 3.5 / Dart 3.5
- State : `flutter_bloc ^8.1.6` + `equatable`
- DI : `get_it ^8.0.3` + `injectable ^2.5.0`
- Réseau : `dio ^5.7.0` + `retrofit ^4.9.0`
- Local : `hive ^2.2.3` + `shared_preferences`
- Paiement : `flutter_stripe ^11.2.0`
- Maps : `google_maps_flutter ^2.10.0` + `geolocator` + `geocoding`
- Firebase : `firebase_core` + `firebase_messaging` + `firebase_analytics`
- Temps réel : `socket_io_client ^3.0.1`
- Monitoring : `sentry_flutter ^8.11.0`

### Couleurs
- Primary : `#FF6B35` (orange)
- Secondary : `#004E89` (bleu)

### Features

| Feature | Statut | Détails |
|---------|--------|---------|
| `orders/` | ✅ Complet | BLoC, Repository, Retrofit, WebSocket watch |
| `auth/` | 🔧 Skeleton | Entités seulement, pages vides, pas de BLoC |
| `restaurants/` | 🔧 Skeleton | Entity seulement |
| `menu/` | 🔧 Skeleton | ProductEntity seulement |
| `payment/` | 🔧 Vide | Stripe importé, rien implémenté |
| `profile/` | 🔧 Vide | Dossier créé, vide |
| `admin/` | 🔧 Vide | Dossier créé, vide |

### Fichiers clés
```
lib/main.dart                                          # Entry + routing basique
lib/core/config/app_config.dart                        # URLs, keys, timeouts
lib/core/di/injection.dart                             # GetIt + Injectable setup
lib/core/network/api_client.dart                       # Dio + Auth/Error interceptors
lib/core/services/websocket_service.dart               # Socket.io (watch orders)
lib/core/utils/location_service.dart                   # GPS + geocoding
lib/core/utils/notification_service.dart               # FCM + local notifications
lib/features/orders/domain/entities/order_entity.dart  # Entity (version simplifiée)
lib/features/orders/presentation/bloc/orders_bloc.dart # BLoC principal
lib/features/orders/data/datasources/order_remote_datasource.dart  # Retrofit endpoints
ARCHITECTURE.md                                        # Docs architecture (497 lignes)
TODO_NEXT_STEPS.md                                     # Roadmap (796 lignes)
```

### BLoC Orders (seul BLoC complet)
```
Events: LoadMyOrders(page) | CreateOrder(params) | CancelOrder(id) | RefreshOrders
States: OrdersInitial → OrdersLoading → OrdersLoaded(orders, hasMorePages) | OrderCreated | OrdersError
```

### Commandes
```bash
cd win_time_mobilapp
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs  # OBLIGATOIRE
flutter run -d chrome
flutter build web
flutter test
```

---

## 4. App restaurateur — `win_time_pro_mobilapp/`

### Stack
- Flutter 3.5 / Dart 3.5
- State : `flutter_bloc ^8.1.6`
- DI : `get_it ^8.0.3` + `injectable ^2.4.4`
- Réseau : `dio ^5.7.0` + `retrofit ^4.4.1`
- Local : `hive ^2.2.3` + `flutter_secure_storage ^9.2.2` (tokens JWT)
- Firebase : `firebase_core` + `firebase_auth` + `firebase_messaging`
- Temps réel : `socket_io_client ^2.0.3`
- Charts : `fl_chart ^0.69.2` + `syncfusion_flutter_charts ^28.1.38`
- Animations : `lottie ^3.2.1`

### Couleurs (différentes de l'app client)
- Primary : `#2563EB` (bleu)
- Secondary : `#10B981` (vert)
- Accent : `#F59E0B` (orange)
- Status commandes : pending=jaune, accepted=bleu, preparing=violet, ready=vert, completed=gris, cancelled=rouge

### Features

| Feature | Entités | BLoC | Data layer | Pages |
|---------|---------|------|------------|-------|
| `auth/` | ✅ UserEntity | ✅ 7 events/7 states | ❌ Vide | ❌ Vide |
| `orders/` | ✅ OrderEntity riche | ✅ 10 events/8 states | ❌ Vide | ❌ Vide |
| `menu/` | ✅ ProductEntity + CategoryEntity | ❌ | ❌ | ❌ |
| `profile/` | ✅ RestaurantEntity complet | ❌ | ❌ | ❌ |
| `statistics/` | ✅ StatisticsEntity nested | ❌ | ❌ | ❌ |
| `dashboard/` | ❌ | ❌ | ❌ | ❌ |

**Note importante** : `main.dart` est en mode démo hardcodé (login: `demo@restaurant.com` / `password`, 6 commandes fictives). Connecter AuthBloc + OrdersBloc pour passer en mode réel.

### BLoC Auth (complet)
```
Events: AuthCheckRequested | AuthLoginRequested | AuthRegisterRequested | AuthLogoutRequested
        AuthForgotPasswordRequested | AuthResetPasswordRequested | AuthVerifyEmailRequested
States: AuthInitial | AuthLoading | AuthAuthenticated(user) | AuthUnauthenticated
        AuthPasswordResetEmailSent | AuthPasswordResetSuccess | AuthEmailVerified | AuthError
```

### BLoC Orders
```
Events: LoadActiveOrders | LoadHistory | AcceptOrder | RejectOrder | MarkReady | Complete
        OrderNewReceived (depuis WebSocket) | RefreshOrders
States: OrdersInitial | OrdersLoading | OrdersLoaded(orders)
        + Getters: pendingOrders / acceptedOrders / preparingOrders / readyOrders
        OrdersHistoryLoaded | OrdersActionInProgress | OrderActionSuccess | OrderNewReceivedNotification | OrdersError
```

### WebSocket (app restaurateur)
```
Rejoint room : 'restaurant:{restaurantId}'
Reçoit :
  'new_order'         → push notification + OrderNewReceived event → BLoC
  'order_updated'     → mise à jour commande (client a modifié)
  'order_cancelled'   → client a annulé
  'menu_updated'      → menu changé depuis autre device
  'restaurant_updated'→ infos changées depuis autre device
```

### Fichiers clés
```
lib/main.dart                                           # Démo screens (1000 lignes)
lib/core/constants/api_constants.dart                   # URLs + tous les endpoints
lib/core/constants/app_constants.dart                   # Clés storage, config
lib/core/network/dio_client.dart                        # Dio + interceptors JWT
lib/core/services/websocket_service.dart                # Socket.IO (room restaurant)
lib/core/services/notification_service.dart             # Firebase + local (fullScreenIntent)
lib/core/theme/app_colors.dart                          # Palette + getOrderStatusColor()
lib/features/orders/domain/entities/order_entity.dart   # Entity riche (30+ champs)
lib/features/auth/presentation/bloc/auth_bloc.dart      # BLoC auth complet
lib/features/orders/presentation/bloc/orders_bloc.dart  # BLoC orders complet
README.md                                               # Setup complet
README_ARCHITECTURE.md                                  # Architecture détaillée
COMMANDS.md                                             # Commandes utiles
```

### Commandes
```bash
cd win_time_pro_mobilapp
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs  # OBLIGATOIRE
flutter run -d chrome
flutter build apk --release
flutter test
```

---

## 5. Package partagé — `packages/shared_core/`

> Tout ce qui doit rester **cohérent** entre les 2 apps va ici.

### Exports complets
```dart
// Entités domaine
UserEntity       // id, email, firstName, lastName, phone, role, isActive...
OrderEntity      // id, orderNumber, items, status, amounts, timeline...
OrderItemEntity  // productId, quantity, unitPrice, options...
CustomerInfo     // name, phoneNumber, email

// Enums (avec extensions FR + méthodes)
UserRole         // client | restaurantOwner | restaurantManager | restaurantStaff | admin
OrderStatus      // pending | accepted | preparing | ready | completed | cancelled | rejected
PaymentStatus    // pending | paid | failed | refunded
PaymentMethod    // creditCard | cash | paypal | applePay | googlePay | other

// Erreurs (pattern Either)
Failure + sous-classes   // Server/Network/Cache/Auth/Authz/NotFound/Validation/Api/WS/Unknown
AppException + sous-classes

// Résultat API (sealed)
ApiResult<T>     // .success(data) | .failure(failure) — avec fold/when/map

// WebSocket
WebSocketService (interface abstraite)
WebSocketConfig, WebSocketState, WebSocketEvents

// Constantes
ApiConstants     // baseUrl, wsBaseUrl, timeouts, endpoints
StorageKeys      // accessToken, refreshToken, cachedUser, cachedRestaurant...

// Utils
DateFormatter    // formatFullDate, formatRelative, formatDuration...
Validators       // validateEmail, validatePassword, validatePhoneNumber...
```

### Règle d'utilisation
- Ajouter dans shared_core : entités métier, enums, contrats d'erreur, interfaces de service
- Garder dans chaque app : implémentations concrètes (Repository, DataSource, BLoC, UI)

---

## 6. Backend — API contractuelle

### URLs
```
REST : https://api.wintime.com/v1
WS   : wss://ws.wintime.com
```

### Endpoints par domaine

**Auth**
```
POST /auth/login
POST /auth/register
POST /auth/logout
POST /auth/refresh
POST /auth/forgot-password
POST /auth/reset-password
POST /auth/verify-email
```

**Restaurants**
```
GET  /restaurants/{id}
PUT  /restaurants/{id}
POST /restaurants/{id}/toggle-availability
```

**Menu**
```
GET|POST        /menu/categories
PUT|DELETE      /menu/categories/{id}
GET|POST        /menu/products
PUT|DELETE      /menu/products/{id}
POST            /menu/products/{id}/toggle-availability
```

**Orders**
```
POST   /orders                      (client: créer)
GET    /orders/me                   (client: mes commandes)
GET    /orders/active               (restaurant: commandes actives)
GET    /orders/history              (restaurant: historique)
GET    /orders/{id}
PATCH  /orders/{id}/cancel          (client)
PATCH  /orders/{id}/status          (générique)
PATCH  /orders/{id}/mark-ready
POST   /orders/{id}/accept          (restaurant)
POST   /orders/{id}/reject          (restaurant)
POST   /orders/{id}/ready           (restaurant)
POST   /orders/{id}/complete        (restaurant)
```

**Stats / Misc**
```
GET  /statistics/dashboard
GET  /statistics/sales
GET  /statistics/performance
POST /notifications/fcm-token
POST /upload/image
GET  /reviews/restaurant/{id}
POST /reviews/{id}/respond
```

### WebSocket — événements

| Événement | Direction | Payload |
|-----------|-----------|---------|
| `join_user` | client → WS | userId |
| `join_restaurant` | resto → WS | restaurantId |
| `watch_order` | client → WS | orderId |
| `unwatch_order` | client → WS | orderId |
| `new_order` | WS → resto | OrderEntity |
| `order_status_updated` | WS → client | {order_id, status} |
| `order_ready` | WS → client | {order_id} |
| `order_cancelled` | WS → les 2 | {order_id, reason} |
| `menu_updated` | WS → resto | {restaurant_id, products} |
| `restaurant_updated` | WS → les 2 | {restaurant_id} |

---

## 7. État actuel & roadmap

### Tableau de bord

| Couche | win_time_mobilapp | win_time_pro_mobilapp |
|--------|-------------------|------------------------|
| Architecture | ✅ Clean + BLoC | ✅ Clean + BLoC |
| DI (GetIt/Injectable) | ✅ | ✅ |
| API client (Dio) | ✅ | ✅ |
| WebSocket service | ✅ | ✅ |
| Notifications | ✅ skeleton | ✅ skeleton |
| Feature Auth | 🔧 entities only | ✅ BLoC / ❌ data+UI |
| Feature Orders | ✅ complet | ✅ BLoC / ❌ data+UI |
| Feature Menu | 🔧 entity only | ✅ entity / ❌ BLoC+data+UI |
| Feature Restaurants/Profile | 🔧 entity only | ✅ entity / ❌ BLoC+data+UI |
| Feature Payment (Stripe) | ❌ | N/A |
| Feature Statistics | N/A | ✅ entity / ❌ BLoC+data+UI |
| Firebase (google-services.json) | ❌ manquant | ❌ manquant |
| Tests | ❌ | ❌ |

### Prochaines étapes recommandées

**Phase 1 — Fondations (blocker)**
1. Ajouter `google-services.json` (Android) + `GoogleService-Info.plist` (iOS) dans les 2 apps
2. Implémenter `auth` data layer (models, datasource, repository) dans les 2 apps
3. Connecter AuthBloc aux pages de login dans les 2 apps

**Phase 2 — Flux principal**
4. Implémenter `restaurants/` + `menu/` (client) — liste, détail, recherche géo
5. Implémenter `menu/` (restaurateur) — CRUD catégories + produits
6. Implémenter cart local (Hive) côté client
7. Intégrer Stripe payment intent (client)

**Phase 3 — Temps réel & Polish**
8. Connecter OrdersBloc aux vraies datasources dans les 2 apps
9. Activer WebSocket dans les 2 apps (remplacer demos)
10. Implémenter Statistics feature (restaurateur) avec fl_chart
11. Tests BLoC + Repository

---

## 8. Gotchas & pièges connus

| Problème | Impact | Solution |
|----------|--------|----------|
| `google-services.json` manquant | Firebase/FCM non fonctionnel | Ajouter le fichier config Firebase dans chaque app |
| `mobile_scanner` désactivé (client) | Scan QR impossible | Conflit `GoogleUtilities` — réactiver quand résolu |
| Code generation obligatoire | Build impossible sans | `flutter pub run build_runner build --delete-conflicting-outputs` |
| 2 `OrderEntity` différentes | Confusion client vs shared_core | `win_time_mobilapp` a sa propre version simplifiée. À terme, migrer vers `shared_core.OrderEntity` |
| `main.dart` pro = démo hardcodé | N'utilise pas les vrais BLoCs | Réécrire en connectant `AuthBloc` + `OrdersBloc` |
| `socket_io_client` versions différentes | Incompatibilité potentielle | Client : `^3.0.1` / Pro : `^2.0.3` — à aligner |
| Token storage | Tokens en mémoire seulement jusqu'à auth implémenté | Utiliser `flutter_secure_storage` (déjà dans pubspec pro) |
| Firebase Auth vs JWT | 2 stratégies d'auth présentes dans pro | Choisir : Firebase Auth OU JWT backend. Éviter les 2. |

---

## 9. Structure monorepo

```
win-time/
├── packages/
│   └── shared_core/          # Package partagé
├── win_time_mobilapp/        # App client
├── win_time_pro_mobilapp/    # App restaurateur
├── legacy/                   # Archives (ne pas toucher)
├── GUIDE_PACKAGE_PARTAGE.md  # Comment utiliser shared_core
├── RESUME_PACKAGE_PARTAGE.md # Résumé de la refacto package
└── WINTIME.md                # CE FICHIER
```
