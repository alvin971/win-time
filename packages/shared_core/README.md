# Shared Core - Win Time

Package partagé pour les applications **Win Time** (client) et **Win Time Pro** (restaurant). Ce package contient toutes les entités, énumérations, constantes et utilitaires communs aux deux applications.

## 📦 Contenu du Package

### Domain Layer

#### Entities
- **UserEntity** : Entité représentant un utilisateur (client ou restaurant)
- **OrderEntity** : Entité représentant une commande
- **OrderItemEntity** : Entité représentant un article dans une commande
- **CustomerInfo** : Informations du client (pour l'app restaurant)

#### Enums
- **UserRole** : Rôles utilisateur (client, restaurantOwner, restaurantManager, restaurantStaff, admin)
- **OrderStatus** : Statuts de commande (pending, accepted, preparing, ready, completed, cancelled, rejected)
- **PaymentStatus** : Statuts de paiement (pending, paid, failed, refunded)
- **PaymentMethod** : Méthodes de paiement (creditCard, cash, paypal, applePay, googlePay, other)

### Core Layer

#### Constants
- **ApiConstants** : Constantes API (URLs, endpoints, timeouts)
- **StorageKeys** : Clés de stockage local

#### Errors
- **Failures** : Classes d'échecs pour le pattern Result
- **Exceptions** : Exceptions personnalisées

#### Network
- **ApiResult** : Pattern Result pour gérer les réponses API

#### WebSocket
- **WebSocketService** : Interface de base pour les services WebSocket
- **WebSocketConfig** : Configuration WebSocket
- **WebSocketEvents** : Événements WebSocket communs

#### Utils
- **DateFormatter** : Utilitaires de formatage de dates
- **Validators** : Validateurs pour formulaires

## 🚀 Installation

Dans le `pubspec.yaml` de votre application :

```yaml
dependencies:
  shared_core:
    path: ../packages/shared_core
```

Puis exécutez :

```bash
flutter pub get
```

## 💡 Utilisation

### Importer le package

```dart
import 'package:shared_core/shared_core.dart';
```

### Utiliser les entités

```dart
// Créer un utilisateur
final user = UserEntity(
  id: '123',
  email: 'user@example.com',
  firstName: 'Jean',
  lastName: 'Dupont',
  role: UserRole.client,
  isActive: true,
  isEmailVerified: true,
  createdAt: DateTime.now(),
);

// Utiliser les extensions
print(user.fullName); // "Jean Dupont"
print(user.initials); // "JD"
print(user.isClient); // true
```

### Utiliser les enums avec extensions

```dart
// OrderStatus avec extension
final status = OrderStatus.preparing;
print(status.displayName); // "En préparation"
print(status.isActive); // true
print(status.isFinished); // false

// PaymentMethod avec extension
final method = PaymentMethod.creditCard;
print(method.displayName); // "Carte bancaire"
print(method.isDigital); // true
```

### Utiliser ApiResult

```dart
// Pattern Result pour gérer les appels API
ApiResult<OrderEntity> result = await orderRepository.getOrder(orderId);

result.when(
  onSuccess: (order) {
    print('Commande récupérée : ${order.orderNumber}');
  },
  onFailure: (failure) {
    print('Erreur : ${failure.message}');
  },
);

// Ou avec fold
final message = result.fold(
  (failure) => 'Erreur : ${failure.message}',
  (order) => 'Commande ${order.orderNumber}',
);
```

### Utiliser les utilitaires de date

```dart
final date = DateTime.now();

// Formatage
print(DateFormatter.formatFullDate(date)); // "2 janvier 2026"
print(DateFormatter.formatShortDate(date)); // "02/01/2026"
print(DateFormatter.formatTime(date)); // "14:30"

// Format relatif
final orderDate = DateTime.now().subtract(Duration(minutes: 15));
print(DateFormatter.formatRelative(orderDate)); // "Il y a 15 minutes"

// Durée
print(DateFormatter.formatDuration(90)); // "1 h 30 min"
```

### Utiliser les validateurs

```dart
// Validation email
String? emailError = Validators.validateEmail('test@example.com');
// null si valide, message d'erreur sinon

// Validation téléphone français
String? phoneError = Validators.validatePhoneNumber('0612345678');

// Combiner plusieurs validateurs
String? error = Validators.combine(value, [
  (v) => Validators.validateRequired(v, fieldName: 'Email'),
  Validators.validateEmail,
]);
```

### Utiliser les constantes

```dart
// Constantes API
print(ApiConstants.baseUrl); // "https://api.wintime.com/v1"
print(ApiConstants.ordersEndpoint); // "/orders"

// Clés de stockage
final token = await storage.read(StorageKeys.accessToken);
```

## 🏗️ Architecture

Le package suit l'architecture Clean Architecture :

```
shared_core/
├── lib/
│   ├── src/
│   │   ├── domain/
│   │   │   ├── entities/      # Entités métier
│   │   │   └── enums/         # Énumérations
│   │   └── core/
│   │       ├── constants/     # Constantes
│   │       ├── errors/        # Gestion d'erreurs
│   │       ├── network/       # Utilitaires réseau
│   │       ├── websocket/     # WebSocket de base
│   │       └── utils/         # Utilitaires
│   └── shared_core.dart       # Point d'entrée
└── pubspec.yaml
```

## 🔄 Compatibilité

- **Flutter** : >= 1.17.0
- **Dart SDK** : ^3.8.1
- Compatible avec **Win Time** (app client) et **Win Time Pro** (app restaurant)

## 📝 Dépendances

- `equatable` : ^2.0.5 - Pour la comparaison d'objets
- `intl` : >=0.19.0 <1.0.0 - Pour l'internationalisation et le formatage de dates

## 🤝 Contribution

Pour contribuer au package partagé :

1. Assurez-vous que les modifications sont pertinentes pour **les deux applications**
2. Ajoutez des tests si nécessaire
3. Mettez à jour ce README si vous ajoutez de nouvelles fonctionnalités
4. Testez dans les deux applications avant de merger

## 📄 Licence

Ce package est privé et propriété de Win Time.

---

**Maintenu par** : L'équipe Win Time
**Version** : 1.0.0
