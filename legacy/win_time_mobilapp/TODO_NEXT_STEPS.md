# 📋 TODO - Prochaines Étapes

## 🎯 Objectif Immédiat : MVP Fonctionnel

Transformer cette base solide en application utilisable.

---

## Phase 1 : Configuration Initiale (1 jour)

### ✅ Déjà Fait
- [x] Structure du projet
- [x] Architecture Clean + BLoC
- [x] Dépendances installées
- [x] Feature Orders complète

### 🔧 À Faire Maintenant

#### 1.1 Générer le Code
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 1.2 Configuration Firebase
- [ ] Créer projet Firebase Console
- [ ] Télécharger `google-services.json` → `android/app/`
- [ ] Télécharger `GoogleService-Info.plist` → `ios/Runner/`
- [ ] Activer Firestore, FCM, Analytics

#### 1.3 Configuration Google Maps
- [ ] Activer Maps SDK (Android + iOS)
- [ ] Créer API keys (2 clés : Android + iOS)
- [ ] Ajouter dans `AndroidManifest.xml` et `Info.plist`
- [ ] Mettre à jour `app_config.dart`

#### 1.4 Configuration Stripe
- [ ] Créer compte Stripe (mode test)
- [ ] Récupérer clé publishable : `pk_test_...`
- [ ] Mettre à jour `app_config.dart`
- [ ] Configurer backend avec clé secrète

#### 1.5 Tester le Setup
```bash
flutter run
```
- [ ] App lance sans erreur
- [ ] Splash screen s'affiche
- [ ] Bottom navigation fonctionne

---

## Phase 2 : Authentification (1-2 semaines)

### 2.1 Backend API Auth Endpoints

Coordonner avec le backend pour avoir :

```
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
GET  /auth/me
```

### 2.2 Domain Layer

**Fichiers à créer :**

```
lib/features/auth/domain/
├── entities/
│   └── user_entity.dart ✅ (déjà créé)
├── repositories/
│   └── auth_repository.dart
└── usecases/
    ├── login_usecase.dart
    ├── register_usecase.dart
    ├── logout_usecase.dart
    ├── get_current_user_usecase.dart
    └── refresh_token_usecase.dart
```

**Exemple `auth_repository.dart` :**

```dart
abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });

  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserEntity>> getCurrentUser();
  Future<Either<Failure, String>> refreshToken();
  Future<String?> getStoredToken();
}
```

### 2.3 Data Layer

**Fichiers à créer :**

```
lib/features/auth/data/
├── models/
│   ├── user_model.dart
│   └── auth_response_model.dart
├── datasources/
│   ├── auth_remote_datasource.dart
│   └── auth_local_datasource.dart
└── repositories/
    └── auth_repository_impl.dart
```

**Exemple `auth_remote_datasource.dart` :**

```dart
@RestApi()
abstract class AuthRemoteDataSource {
  @POST('/auth/login')
  Future<AuthResponseModel> login(@Body() Map<String, dynamic> data);

  @POST('/auth/register')
  Future<AuthResponseModel> register(@Body() Map<String, dynamic> data);

  @POST('/auth/refresh')
  Future<AuthResponseModel> refreshToken(@Body() Map<String, dynamic> data);
}
```

### 2.4 Presentation Layer

**Fichiers à créer :**

```
lib/features/auth/presentation/
├── bloc/
│   ├── auth_bloc.dart
│   ├── auth_event.dart
│   └── auth_state.dart
├── pages/
│   ├── login_page.dart
│   ├── register_page.dart
│   └── splash_page.dart
└── widgets/
    ├── login_form.dart
    └── register_form.dart
```

### 2.5 Token Management

**Créer `lib/core/utils/token_manager.dart` :**

```dart
@singleton
class TokenManager {
  final FlutterSecureStorage storage;

  Future<void> saveToken(String token) async {
    await storage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    return await storage.read(key: 'auth_token');
  }

  Future<void> deleteToken() async {
    await storage.delete(key: 'auth_token');
  }
}
```

### 2.6 Auto-Login

Modifier `main.dart` :

```dart
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(Duration(seconds: 2));

    final authBloc = getIt<AuthBloc>();
    final hasToken = await authBloc.checkAuthentication();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => hasToken ? HomePage() : LoginPage(),
        ),
      );
    }
  }
}
```

### 2.7 Checklist Auth

- [ ] Créer tous les fichiers domain
- [ ] Créer tous les fichiers data
- [ ] Créer tous les fichiers presentation
- [ ] Implémenter UI login/register
- [ ] Tester login avec credentials
- [ ] Tester register nouveau compte
- [ ] Tester auto-login au démarrage
- [ ] Tester logout
- [ ] Gérer erreurs (mauvais mdp, email déjà utilisé, etc.)

---

## Phase 3 : Restaurants (1 semaine)

### 3.1 Backend Endpoints

```
GET  /restaurants?lat=...&lng=...&radius=...
GET  /restaurants/:id
GET  /restaurants/search?q=...&cuisine=...
```

### 3.2 À Implémenter

**Domain :**
- [x] `restaurant_entity.dart` ✅ (déjà créé)
- [ ] `restaurant_repository.dart`
- [ ] `get_nearby_restaurants_usecase.dart`
- [ ] `search_restaurants_usecase.dart`
- [ ] `get_restaurant_detail_usecase.dart`

**Data :**
- [ ] `restaurant_model.dart`
- [ ] `restaurant_remote_datasource.dart`
- [ ] `restaurant_repository_impl.dart`

**Presentation :**
- [ ] `restaurants_bloc.dart`
- [ ] `restaurants_page.dart` (liste + map)
- [ ] `restaurant_detail_page.dart`
- [ ] `restaurant_card.dart` widget
- [ ] `restaurant_filters.dart` widget

### 3.3 Features Spécifiques

**Recherche Géolocalisée :**
```dart
// Utiliser LocationService déjà créé
final position = await locationService.getCurrentPosition();
final restaurants = await getNearbyRestaurantsUseCase(
  latitude: position.latitude,
  longitude: position.longitude,
  radius: 5.0, // km
);
```

**Filtres :**
- [ ] Par type de cuisine
- [ ] Par prix (€ à €€€€)
- [ ] Par temps de préparation
- [ ] Par note moyenne

**Carte Interactive :**
```dart
GoogleMap(
  markers: restaurants.map((r) => Marker(
    markerId: MarkerId(r.id),
    position: LatLng(r.latitude, r.longitude),
  )).toSet(),
)
```

### 3.4 Checklist Restaurants

- [ ] Implémenter domain layer
- [ ] Implémenter data layer
- [ ] UI liste restaurants
- [ ] UI carte Google Maps
- [ ] Filtres fonctionnels
- [ ] Recherche textuelle
- [ ] Navigation vers détail
- [ ] Affichage horaires d'ouverture
- [ ] Affichage note/avis

---

## Phase 4 : Menu & Panier (2 semaines)

### 4.1 Backend Endpoints

```
GET  /restaurants/:id/menu
GET  /products/:id
POST /cart/add
GET  /cart
DELETE /cart/item/:id
POST /cart/validate
```

### 4.2 À Implémenter

**Domain :**
- [x] `product_entity.dart` ✅ (déjà créé)
- [ ] `cart_entity.dart`
- [ ] `menu_repository.dart`
- [ ] `cart_repository.dart`
- [ ] `get_menu_usecase.dart`
- [ ] `add_to_cart_usecase.dart`

**Data :**
- [ ] `product_model.dart`
- [ ] `cart_model.dart`
- [ ] `menu_remote_datasource.dart`
- [ ] `cart_local_datasource.dart` (Hive)

**Presentation :**
- [ ] `menu_bloc.dart`
- [ ] `cart_bloc.dart`
- [ ] `menu_page.dart`
- [ ] `product_detail_page.dart`
- [ ] `cart_page.dart`
- [ ] `product_card.dart`
- [ ] `cart_item_widget.dart`

### 4.3 Gestion du Panier

**Stockage Local (Hive) :**

```dart
@HiveType(typeId: 0)
class CartItemModel {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final int quantity;

  @HiveField(2)
  final Map<String, dynamic>? options;
}
```

**Features :**
- [ ] Ajout au panier
- [ ] Modification quantité
- [ ] Suppression article
- [ ] Calcul total
- [ ] Personnalisation produit (options)
- [ ] Persistance locale
- [ ] Badge sur icône panier

### 4.4 Personnalisation Produits

**UI pour options :**
```dart
// Exemple : Taille (Petit, Moyen, Grand)
// Exemple : Extras (Fromage +1€, Bacon +1.50€)
```

- [ ] Radio buttons pour choix unique
- [ ] Checkboxes pour choix multiples
- [ ] Champ texte pour instructions spéciales

### 4.5 Checklist Menu & Panier

- [ ] Affichage menu par catégories
- [ ] Détail produit avec photo
- [ ] Options/personnalisation
- [ ] Ajout au panier
- [ ] Page panier
- [ ] Modification quantité
- [ ] Calcul total dynamique
- [ ] Bouton "Commander"

---

## Phase 5 : Paiement Stripe (1 semaine)

### 5.1 Backend Endpoints

```
POST /payments/create-intent
POST /payments/confirm
GET  /payments/methods
POST /payments/methods/add
```

### 5.2 Flux de Paiement

1. Client valide panier
2. App demande Payment Intent au backend
3. Backend crée Intent Stripe (secret)
4. App affiche formulaire carte (SDK Stripe)
5. Client saisit carte
6. App confirme paiement
7. Stripe valide
8. Backend crée la commande
9. App affiche confirmation

### 5.3 À Implémenter

**Domain :**
- [ ] `payment_method_entity.dart`
- [ ] `payment_repository.dart`
- [ ] `create_payment_intent_usecase.dart`
- [ ] `confirm_payment_usecase.dart`

**Data :**
- [ ] `payment_remote_datasource.dart`

**Presentation :**
- [ ] `payment_page.dart`
- [ ] `payment_bloc.dart`
- [ ] `card_input_widget.dart`

### 5.4 Intégration Stripe

**Setup :**

```dart
void main() async {
  Stripe.publishableKey = AppConfig.stripePublishableKey;
  runApp(WinTimeApp());
}
```

**Payment Sheet :**

```dart
final paymentIntent = await createPaymentIntentUseCase(amount);

await Stripe.instance.initPaymentSheet(
  paymentSheetParameters: SetupPaymentSheetParameters(
    paymentIntentClientSecret: paymentIntent.clientSecret,
    merchantDisplayName: 'Win Time',
  ),
);

await Stripe.instance.presentPaymentSheet();
```

### 5.5 Checklist Paiement

- [ ] Configuration Stripe
- [ ] UI sélection moyen de paiement
- [ ] Formulaire carte bancaire
- [ ] Création Payment Intent
- [ ] Confirmation paiement
- [ ] Gestion erreurs paiement
- [ ] Sauvegarde carte pour plus tard
- [ ] Feedback utilisateur (success/error)

---

## Phase 6 : Commandes Complètes (3 jours)

### 6.1 Compléter Orders Feature

**Déjà fait :**
- [x] Liste commandes ✅
- [x] Création commande ✅
- [x] Annulation ✅

**À ajouter :**
- [ ] Page détail commande
- [ ] Suivi temps réel (WebSocket ou polling)
- [ ] QR Code pour retrait
- [ ] Notation après retrait

### 6.2 WebSocket pour Temps Réel

**Setup Socket.io :**

```dart
@singleton
class SocketService {
  late IO.Socket socket;

  void connect(String orderId) {
    socket = IO.io(AppConfig.wsBaseUrl);
    socket.on('order:$orderId:update', (data) {
      // Émettre event BLoC pour update
    });
  }
}
```

### 6.3 QR Code

**Génération :**
```dart
QrImageView(
  data: order.id,
  version: QrVersions.auto,
  size: 200.0,
)
```

**Scan (côté restaurant) :**
```dart
MobileScanner(
  onDetect: (capture) {
    final orderId = capture.barcodes.first.rawValue;
    // Marquer commande comme retirée
  },
)
```

### 6.4 Checklist Commandes

- [ ] Page détail commande
- [ ] Timeline de statut
- [ ] Temps restant estimation
- [ ] Notification push statut changé
- [ ] QR Code pour retrait
- [ ] Bouton "Problème avec ma commande"
- [ ] Notation/avis après retrait

---

## Phase 7 : Profil Utilisateur (1 semaine)

### 7.1 À Implémenter

- [ ] Affichage infos utilisateur
- [ ] Édition profil
- [ ] Gestion adresses
- [ ] Moyens de paiement sauvegardés
- [ ] Historique complet commandes
- [ ] Paramètres notifications
- [ ] Dark mode toggle
- [ ] Déconnexion

---

## Phase 8 : Panel Restaurateur (3-4 semaines)

### 8.1 Dashboard Temps Réel

- [ ] Commandes en cours
- [ ] Notifications nouvelles commandes
- [ ] Son d'alerte
- [ ] Boutons Accepter/Refuser

### 8.2 Gestion Menu

- [ ] CRUD produits
- [ ] Upload photos
- [ ] Gestion catégories
- [ ] Toggle disponibilité
- [ ] Gestion options produits

### 8.3 Système d'Estimation Intelligent

**Principe :**
- Estimation initiale par le restaurateur
- Enregistrement temps réel de préparation
- Machine learning simple pour ajuster

**Table `preparation_history` :**
```
order_id, product_id, estimated_time, actual_time, created_at
```

**Algorithme :**
```dart
newEstimate = (oldEstimate * 0.7) + (actualTime * 0.3)
```

### 8.4 Statistiques

- [ ] Graphiques ventes journalières
- [ ] Top produits
- [ ] Revenus mensuels
- [ ] Temps moyen préparation
- [ ] Taux satisfaction

---

## Phase 9 : Notifications Push (3 jours)

### 9.1 Types de Notifications

**Pour Clients :**
- Commande acceptée
- Commande en préparation
- Commande prête
- Promotion restaurant favori

**Pour Restaurants :**
- Nouvelle commande
- Alerte retard préparation

### 9.2 Implementation

**Déjà créé :**
- [x] `notification_service.dart` ✅

**À faire :**
- [ ] Demander permission au démarrage
- [ ] Enregistrer token FCM en backend
- [ ] Subscribe à topics (user_id, restaurant_id)
- [ ] Gérer navigation depuis notification
- [ ] Notification locale pour foreground

### 9.3 Backend

Backend doit envoyer via Firebase Admin SDK :

```json
{
  "to": "FCM_TOKEN",
  "notification": {
    "title": "Commande prête !",
    "body": "Votre commande #12345 est prête"
  },
  "data": {
    "type": "order_ready",
    "order_id": "order-123"
  }
}
```

---

## Phase 10 : Tests & QA (1 semaine)

### 10.1 Tests à Écrire

**Unit Tests :**
- [ ] Tous les Use Cases
- [ ] Tous les Repositories

**BLoC Tests :**
- [ ] Auth BLoC
- [ ] Restaurants BLoC
- [ ] Menu BLoC
- [ ] Cart BLoC
- [ ] Payment BLoC

**Widget Tests :**
- [ ] Pages principales
- [ ] Widgets réutilisables

**Integration Tests :**
- [ ] Parcours complet commande
- [ ] Login → Search → Menu → Cart → Payment → Order

### 10.2 Coverage Goal

Target : **80%+ coverage**

```bash
flutter test --coverage
```

### 10.3 Checklist QA

- [ ] Tests passent tous
- [ ] Pas de warnings `flutter analyze`
- [ ] Performance (temps chargement < 3s)
- [ ] Responsive (tablette + phone)
- [ ] Dark mode cohérent
- [ ] Accessibilité (semantic labels)
- [ ] Gestion erreurs réseau
- [ ] Offline message

---

## Phase 11 : Déploiement (3-5 jours)

### 11.1 Android

- [ ] Générer keystore production
- [ ] Configurer `key.properties`
- [ ] Build App Bundle
- [ ] Créer compte Play Console
- [ ] Créer fiche application
- [ ] Screenshots
- [ ] Description
- [ ] Upload AAB
- [ ] Review Google (2-7 jours)

### 11.2 iOS

- [ ] Compte Apple Developer (99$/an)
- [ ] Créer App ID
- [ ] Provisioning profiles
- [ ] Build IPA
- [ ] Créer fiche App Store Connect
- [ ] Screenshots (tous formats)
- [ ] Upload via Xcode
- [ ] Review Apple (1-3 jours)

### 11.3 Backend Production

- [ ] Déployer API production
- [ ] Configurer HTTPS
- [ ] Variables environnement
- [ ] Base de données production
- [ ] Monitoring (Sentry)
- [ ] Logs

---

## 📊 Estimation Temps Total

| Phase | Durée | Priorité |
|-------|-------|----------|
| 1. Configuration | 1j | 🔴 Critique |
| 2. Auth | 1-2sem | 🔴 Critique |
| 3. Restaurants | 1sem | 🔴 Critique |
| 4. Menu & Panier | 2sem | 🔴 Critique |
| 5. Paiement | 1sem | 🔴 Critique |
| 6. Orders complet | 3j | 🟠 Important |
| 7. Profil | 1sem | 🟠 Important |
| 8. Panel Resto | 3-4sem | 🟡 Moyen |
| 9. Notifications | 3j | 🟠 Important |
| 10. Tests & QA | 1sem | 🟠 Important |
| 11. Déploiement | 3-5j | 🔴 Critique |

**Total : 10-12 semaines** pour un MVP complet

---

## 🎯 Roadmap Recommandée

### Sprint 1 (2 semaines) - MVP Minimal
1. Configuration complète
2. Authentification
3. Liste restaurants basique

### Sprint 2 (2 semaines) - Commande
4. Menu & Panier
5. Paiement Stripe

### Sprint 3 (1 semaine) - Polish
6. Orders détail
7. Notifications
8. Tests

### Sprint 4+ - Fonctionnalités Avancées
9. Panel restaurateur
10. Admin
11. Analytics

---

## 🚀 Démarrer Maintenant

**Action immédiate :**

```bash
cd "/Users/alvinkuyo/Downloads/win time"

# 1. Installer dépendances
flutter pub get

# 2. Générer code
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Lancer
flutter run
```

**Puis suivre Phase 1 ci-dessus.**

---

## 📞 Ressources & Aide

- **Architecture** : Lire `ARCHITECTURE.md`
- **Setup** : Lire `SETUP.md`
- **Commandes** : Lire `COMMANDS.md`
- **Exemple complet** : `lib/features/orders/`

**En cas de blocage :**
1. Consulter la documentation
2. Chercher dans le code existant (Orders feature)
3. Dupliquer le pattern

Bon développement ! 🚀
