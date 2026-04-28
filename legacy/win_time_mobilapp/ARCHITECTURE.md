# Architecture Technique - Win Time

## 📐 Vue d'Ensemble

Win Time utilise une **Clean Architecture** basée sur les principes SOLID, garantissant :
- ✅ Séparation des responsabilités
- ✅ Testabilité maximale
- ✅ Indépendance des frameworks
- ✅ Maintenabilité à long terme
- ✅ Scalabilité

## 🏗️ Schéma de l'Architecture

```
┌─────────────────────────────────────────────────────┐
│                  PRESENTATION LAYER                  │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │    Pages     │  │    Widgets   │  │   BLoCs   │ │
│  │  (Screens)   │  │ (Components) │  │ (States)  │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│                   DOMAIN LAYER                       │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │   Entities   │  │  Use Cases   │  │Repository │ │
│  │  (Business)  │  │   (Logic)    │  │ Interface │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│                    DATA LAYER                        │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │    Models    │  │ Data Sources │  │Repository │ │
│  │    (DTOs)    │  │  (API/DB)    │  │   Impl    │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└─────────────────────────────────────────────────────┘
```

## 🎯 Principe de Dépendance

```
Presentation ──depends on──> Domain <──depends on── Data
```

**Règle d'or** : Les dépendances vont toujours **vers l'intérieur** (vers le domain).

## 📦 Détail des Couches

### 1️⃣ Presentation Layer

**Responsabilité** : Affichage et interaction utilisateur

#### Composants

**Pages (Screens)**
- Écrans complets de l'application
- Consomment les BLoCs
- Gèrent la navigation
- Exemple : `orders_page.dart`

**Widgets**
- Composants UI réutilisables
- Stateless ou Stateful
- Pas de logique métier
- Exemple : `order_card.dart`

**BLoC (Business Logic Component)**
- Gestion d'état
- Transforme les Events en States
- Communique avec les Use Cases
- Exemple : `orders_bloc.dart`

```dart
// Exemple de flux BLoC
User clicks button
    ↓
Event dispatched (CreateOrder)
    ↓
BLoC receives event
    ↓
Calls Use Case
    ↓
Emits State (OrderCreated)
    ↓
UI rebuilds
```

#### Pattern BLoC vs Autres

| Pattern | Avantages | Inconvénients |
|---------|-----------|---------------|
| **BLoC** | Reactive, testable, séparation claire | Verbosité |
| Riverpod | Moderne, moins verbeux | Nouvelle syntaxe |
| Provider | Simple, natif | Peut devenir complexe |
| GetX | Tout-en-un | Magie, couplage |

**Choix** : BLoC pour sa maturité et testabilité.

### 2️⃣ Domain Layer

**Responsabilité** : Logique métier pure (indépendante du framework)

#### Entities

Objets métier sans dépendance :

```dart
class OrderEntity extends Equatable {
  final String id;
  final double totalAmount;
  final OrderStatus status;
  // ...

  // Logique métier
  bool get canBeCancelled => status == OrderStatus.pending;
}
```

**Caractéristiques** :
- Immutables (final)
- Extends Equatable (comparaison)
- Pas de JSON, pas de Firebase, pas de Dio
- Pure Dart

#### Use Cases

Une action métier = Un use case :

```dart
class CreateOrderUseCase implements UseCase<OrderEntity, CreateOrderParams> {
  final OrderRepository repository;

  @override
  Future<Either<Failure, OrderEntity>> call(CreateOrderParams params) async {
    // Validation métier
    if (params.items.isEmpty) {
      return Left(ValidationFailure(...));
    }

    // Appel repository
    return await repository.createOrder(params);
  }
}
```

**Principe** :
- Single Responsibility
- Testable indépendamment
- Retourne `Either<Failure, Success>` (gestion erreur fonctionnelle)

#### Repositories (Interfaces)

Contrats abstraits :

```dart
abstract class OrderRepository {
  Future<Either<Failure, OrderEntity>> createOrder(CreateOrderParams params);
  Future<Either<Failure, List<OrderEntity>>> getMyOrders();
  // ...
}
```

### 3️⃣ Data Layer

**Responsabilité** : Accès aux données (API, DB, cache)

#### Models (DTOs)

Objets pour sérialisation JSON :

```dart
@JsonSerializable()
class OrderModel {
  @JsonKey(name: 'order_number')
  final String orderNumber;

  OrderModel({required this.orderNumber});

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  OrderEntity toEntity() => OrderEntity(...);
}
```

**Différence Model vs Entity** :

| Aspect | Entity | Model |
|--------|--------|-------|
| Couche | Domain | Data |
| Dépendances | Aucune | json_annotation |
| But | Logique métier | Sérialisation |
| Mutabilité | Immutable | Immutable |

#### Data Sources

Sources de données (API, DB) :

```dart
@RestApi()
abstract class OrderRemoteDataSource {
  @POST('/orders')
  Future<OrderModel> createOrder(@Body() Map<String, dynamic> data);
}
```

**Types** :
- **Remote** : API REST (Retrofit + Dio)
- **Local** : Hive, SQLite, Shared Preferences
- **Cache** : Redis, in-memory

#### Repository Implementation

Implémente les contrats :

```dart
@LazySingleton(as: OrderRepository)
class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, OrderEntity>> createOrder(...) async {
    try {
      final model = await remoteDataSource.createOrder(data);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }
}
```

**Responsabilités** :
- Orchestrer remote + local + cache
- Transformer Models → Entities
- Gérer les exceptions → Failures

## 🔧 Dependency Injection

### get_it + injectable

```dart
// Service Locator
final getIt = GetIt.instance;

// Auto-registration avec @injectable
@module
abstract class RegisterModule {
  @singleton
  Dio get dio => Dio();
}

// Usage
final bloc = getIt<OrdersBloc>();
```

**Avantages** :
- Registration automatique (code generation)
- Type-safe
- Testable (mock injection)

### Scopes

| Annotation | Lifecycle | Usage |
|------------|-----------|-------|
| `@singleton` | Une seule instance | Services globaux |
| `@lazySingleton` | Créé à la première demande | Repositories |
| `@injectable` | Nouvelle instance à chaque fois | BLoCs |

## 🔄 Flux de Données Complet

### Exemple : Créer une commande

```
1. User taps "Commander" button
   ↓
2. Page dispatches CreateOrder event
   ↓
3. OrdersBloc receives event
   ↓
4. Bloc calls CreateOrderUseCase
   ↓
5. UseCase validates business rules
   ↓
6. UseCase calls OrderRepository.createOrder()
   ↓
7. OrderRepositoryImpl calls OrderRemoteDataSource
   ↓
8. API request via Dio (POST /orders)
   ↓
9. Server responds with OrderModel JSON
   ↓
10. Model converts to OrderEntity
   ↓
11. Repository returns Right(orderEntity)
   ↓
12. UseCase returns to Bloc
   ↓
13. Bloc emits OrderCreated(order) state
   ↓
14. BlocBuilder rebuilds UI
   ↓
15. Success screen displayed
```

## 🧪 Testabilité

### Tests Unitaires

```dart
test('CreateOrderUseCase returns failure when items empty', () async {
  // Arrange
  final useCase = CreateOrderUseCase(mockRepository);
  final params = CreateOrderParams(items: []);

  // Act
  final result = await useCase(params);

  // Assert
  expect(result, isA<Left>());
  expect(result.fold((l) => l, (r) => null), isA<ValidationFailure>());
});
```

### Tests BLoC

```dart
blocTest<OrdersBloc, OrdersState>(
  'emits OrderCreated when CreateOrder succeeds',
  build: () => OrdersBloc(repository, useCase),
  act: (bloc) => bloc.add(CreateOrder(validParams)),
  expect: () => [OrderCreating(), OrderCreated(order)],
);
```

### Tests Widget

```dart
testWidgets('OrderCard displays order number', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OrderCard(order: testOrder, onTap: () {}),
    ),
  );

  expect(find.text('Commande #12345'), findsOneWidget);
});
```

## 🚀 Performance

### Optimisations

1. **Lazy loading** : Liste des commandes avec pagination
2. **Cache** : Images avec `cached_network_image`
3. **Debouncing** : Recherche de restaurants
4. **Memoization** : BLoC states avec Equatable
5. **Code splitting** : Navigation avec go_router

### Monitoring

- Sentry pour les crashs
- Firebase Analytics pour les metrics
- Custom logging pour debug

## 📱 Navigation

### go_router

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomePage(),
    ),
    GoRoute(
      path: '/restaurant/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RestaurantDetailPage(restaurantId: id);
      },
    ),
  ],
);
```

**Avantages** :
- Deep linking
- Type-safe navigation
- Back button handling
- Web support

## 🔐 Sécurité

### Stockage des tokens

```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: token);
```

### Validation des entrées

```dart
// Dans les Use Cases
if (!EmailValidator.validate(email)) {
  return Left(ValidationFailure(...));
}
```

### API Security

- HTTPS obligatoire
- JWT avec expiration
- Refresh tokens
- Rate limiting côté backend

## 📊 State Management Comparison

| Critère | BLoC | Riverpod | GetX |
|---------|------|----------|------|
| Courbe apprentissage | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| Verbosité | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Testabilité | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Documentation | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Communauté | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Performance | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

**Recommandation** : BLoC pour sa maturité et son écosystème.

## 🎨 Conventions de Code

### Nommage

```dart
// Classes : PascalCase
class OrderEntity {}

// Fichiers : snake_case
order_entity.dart

// Variables/fonctions : camelCase
final orderTotal = 100.0;
void calculateTotal() {}

// Constantes : camelCase
const maxOrderItems = 10;

// Enums : PascalCase
enum OrderStatus { pending, accepted }
```

### Organisation

```dart
// 1. Imports (classés)
import 'package:flutter/material.dart';

import 'package:win_time/core/...';
import 'package:win_time/features/...';

// 2. Class declaration
class OrdersPage extends StatelessWidget {
  // 3. Fields
  final String title;

  // 4. Constructor
  const OrdersPage({required this.title});

  // 5. Overrides
  @override
  Widget build(BuildContext context) {}

  // 6. Private methods
  void _privateMethod() {}
}
```

## 📚 Ressources Complémentaires

- [Clean Architecture (Uncle Bob)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [BLoC Library](https://bloclibrary.dev)
- [Reso Coder Tutorials](https://resocoder.com)
- [Flutter Architecture Samples](https://github.com/brianegan/flutter_architecture_samples)

## 🔄 Évolutions Futures

1. **Offline-first** : Sync automatique avec backend
2. **Microservices** : Séparation des features en packages
3. **Feature flags** : Toggle features sans redéploiement
4. **A/B Testing** : Tests de variantes UI
5. **GraphQL** : Alternative à REST pour optimiser les requêtes
