# Win Time - Plateforme Click & Collect pour Restaurants

Application mobile Flutter pour la commande en ligne et le retrait de commandes dans les restaurants (Click & Collect).

## 📱 Plateforme

- **iOS** : 13.0+
- **Android** : API 24+ (Android 7.0+)
- **Flutter** : 3.5.0+

## 🏗️ Architecture

Le projet suit une **Clean Architecture** avec le pattern **BLoC** pour la gestion d'état.

```
lib/
├── core/                      # Code partagé entre features
│   ├── config/               # Configuration (API, constantes)
│   ├── di/                   # Dependency Injection (get_it)
│   ├── errors/               # Gestion erreurs et exceptions
│   ├── network/              # Client API (Dio)
│   ├── theme/                # Thème Material Design 3
│   ├── usecases/             # Base use cases
│   ├── utils/                # Utilitaires (notifications, location)
│   └── widgets/              # Widgets réutilisables
│
├── features/                  # Fonctionnalités métier
│   ├── auth/                 # Authentification
│   ├── restaurants/          # Découverte restaurants
│   ├── orders/               # Gestion commandes
│   ├── menu/                 # Menus et produits
│   ├── profile/              # Profil utilisateur
│   ├── payment/              # Paiements Stripe
│   └── admin/                # Panel administrateur
│       ├── data/
│       │   ├── datasources/  # Sources de données (API)
│       │   ├── models/       # DTOs / Models JSON
│       │   └── repositories/ # Implémentation repositories
│       ├── domain/
│       │   ├── entities/     # Objets métier
│       │   ├── repositories/ # Contrats abstraits
│       │   └── usecases/     # Logique métier
│       └── presentation/
│           ├── bloc/         # BLoC (Events, States)
│           ├── pages/        # Écrans
│           └── widgets/      # Composants UI
│
└── main.dart                 # Point d'entrée
```

## 🔧 Principes de Clean Architecture

### 1. Couche Domain (Métier)
- **Entities** : Objets métier purs (pas de dépendance externe)
- **Repositories** : Interfaces abstraites
- **Use Cases** : Logique métier isolée

### 2. Couche Data (Données)
- **Models** : DTOs pour sérialisation JSON
- **Data Sources** : API REST (Retrofit + Dio)
- **Repository Impl** : Implémentation des contrats

### 3. Couche Presentation (UI)
- **BLoC** : Gestion d'état reactive
- **Pages** : Écrans de l'application
- **Widgets** : Composants UI réutilisables

## 📦 Packages Principaux

### State Management & DI
- `flutter_bloc` ^8.1.6 - Gestion d'état
- `get_it` ^8.0.3 - Service locator
- `injectable` ^2.5.0 - Code generation DI

### Network
- `dio` ^5.7.0 - HTTP client
- `retrofit` ^4.5.0 - REST client
- `socket_io_client` ^3.0.1 - WebSocket

### Firebase
- `firebase_core` ^3.8.1
- `firebase_messaging` ^15.1.5 - Push notifications
- `cloud_firestore` ^5.5.2 - Base de données

### UI/UX
- `cached_network_image` ^3.4.1 - Cache images
- `shimmer` ^3.0.0 - Loading skeleton
- `flutter_rating_bar` ^4.0.1 - Notation
- `carousel_slider` ^5.0.0 - Carousel

### Autres
- `google_maps_flutter` ^2.10.0 - Maps
- `flutter_stripe` ^11.2.0 - Paiements
- `hive` ^2.2.3 - Local storage

## 🚀 Installation

### 1. Cloner le projet

```bash
git clone <repository-url>
cd win_time
```

### 2. Installer les dépendances

```bash
flutter pub get
```

### 3. Générer le code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Configuration Firebase

1. Créer un projet Firebase sur [console.firebase.google.com](https://console.firebase.google.com)
2. Télécharger `google-services.json` (Android) → `android/app/`
3. Télécharger `GoogleService-Info.plist` (iOS) → `ios/Runner/`
4. Activer Firebase Messaging et Firestore

### 5. Configuration API

Modifier les variables dans `lib/core/config/app_config.dart` :

```dart
static const String apiBaseUrl = 'https://votre-api.com/v1';
static const String stripePublishableKey = 'pk_live_YOUR_KEY';
static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_KEY';
```

### 6. Lancer l'application

```bash
# Mode debug
flutter run

# Mode release
flutter run --release
```

## 🧪 Tests

```bash
# Tests unitaires
flutter test

# Tests avec coverage
flutter test --coverage

# Tests d'intégration
flutter test integration_test/
```

## 📱 Build Production

### Android

```bash
# Générer l'APK
flutter build apk --release

# Générer l'App Bundle (recommandé pour Play Store)
flutter build appbundle --release
```

### iOS

```bash
# Générer l'IPA
flutter build ipa --release
```

## 🔑 Fonctionnalités Clés

### Pour les Clients
- ✅ Recherche de restaurants par localisation
- ✅ Consultation des menus avec photos
- ✅ Personnalisation des produits (options, extras)
- ✅ Paiement sécurisé (Stripe)
- ✅ Suivi de commande en temps réel
- ✅ Notifications push
- ✅ Historique des commandes

### Pour les Restaurateurs
- ✅ Tableau de bord temps réel
- ✅ Gestion du menu (CRUD produits)
- ✅ Réception et acceptation des commandes
- ✅ Système d'estimation de temps intelligent
- ✅ Statistiques et rapports
- ✅ Gestion de la disponibilité

### Système d'Estimation Intelligent
Le système apprend progressivement des temps réels de préparation :
- Estimation initiale définie par le restaurateur
- Ajustement automatique basé sur l'historique
- Prise en compte de l'heure, du jour, et de la charge

## 🔐 Sécurité

- Authentification JWT avec refresh tokens
- Stockage sécurisé (flutter_secure_storage)
- Validation des entrées utilisateur
- Protection CSRF/XSS
- Conformité RGPD

## 💳 Modèle Économique

- **Abonnement mensuel** : 100€
- **Commission par commande** : 0,10€
- **Seuil inclus** : 1000 commandes/mois
- **Au-delà** : Facturation du surplus

## 🌍 Internationalisation

Le projet est prêt pour l'i18n avec le package `intl`.

```dart
// Exemple
DateFormat('dd/MM/yyyy').format(date);
NumberFormat.currency(symbol: '€').format(price);
```

## 📚 Ressources

- [Documentation Flutter](https://docs.flutter.dev/)
- [BLoC Pattern](https://bloclibrary.dev/)
- [Firebase Flutter](https://firebase.google.com/docs/flutter/setup)
- [Stripe Flutter](https://stripe.com/docs/payments/accept-a-payment?platform=flutter)

## 🤝 Contribution

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📄 Licence

Ce projet est sous licence propriétaire. Tous droits réservés.

## 👥 Équipe

- **Product Owner** : [Nom]
- **Lead Developer** : [Nom]
- **UI/UX Designer** : [Nom]

## 📞 Support

Pour toute question ou problème :
- Email : support@wintime.com
- Documentation : https://docs.wintime.com
