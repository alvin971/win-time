# 📦 Guide du Package Partagé Win Time

## Vue d'ensemble

Le package `shared_core` contient tout le code commun entre **Win Time** (app client) et **Win Time Pro** (app restaurant). Cela représente environ **40% du code** qui était dupliqué entre les deux applications.

## 🎯 Avantages

### 1. DRY (Don't Repeat Yourself)
- Une seule source de vérité pour les entités communes
- Maintenance simplifiée : modifier une fois, propager partout
- Réduction des bugs liés à la duplication de code

### 2. Cohérence
- Les mêmes entités et logiques métier dans les deux apps
- Garantit que client et restaurant parlent le même "langage"
- Synchronisation automatique des modifications

### 3. Performance
- Réduction de la taille totale du projet
- Moins de code à maintenir et tester
- Build plus rapides

## 📁 Structure du Projet

```
win_time/
├── packages/
│   └── shared_core/              # 📦 Package partagé (40% code commun)
│       ├── lib/
│       │   ├── src/
│       │   │   ├── domain/
│       │   │   │   ├── entities/
│       │   │   │   │   ├── user_entity.dart
│       │   │   │   │   └── order_entity.dart
│       │   │   │   └── enums/
│       │   │   │       ├── user_role.dart
│       │   │   │       ├── order_status.dart
│       │   │   │       ├── payment_status.dart
│       │   │   │       └── payment_method.dart
│       │   │   └── core/
│       │   │       ├── constants/
│       │   │       │   ├── api_constants.dart
│       │   │       │   └── storage_keys.dart
│       │   │       ├── errors/
│       │   │       │   ├── failures.dart
│       │   │       │   └── exceptions.dart
│       │   │       ├── network/
│       │   │       │   └── api_result.dart
│       │   │       ├── websocket/
│       │   │       │   └── websocket_service.dart
│       │   │       └── utils/
│       │   │           ├── date_formatter.dart
│       │   │           └── validators.dart
│       │   └── shared_core.dart
│       ├── pubspec.yaml
│       └── README.md
│
├── win_time_mobilapp copie/      # 🛍️ App Client (60% code spécifique)
│   ├── lib/
│   │   ├── features/
│   │   │   ├── restaurants/      # Découverte restaurants
│   │   │   ├── orders/           # Passer commande
│   │   │   ├── menu/             # Consulter menus
│   │   │   ├── payment/          # Paiement Stripe
│   │   │   └── profile/
│   │   └── main.dart
│   └── pubspec.yaml
│
└── win_time_pro_mobilapp copie/  # 🍽️ App Restaurant (60% code spécifique)
    ├── lib/
    │   ├── features/
    │   │   ├── dashboard/        # Tableau de bord
    │   │   ├── orders/           # Gérer commandes
    │   │   ├── statistics/       # Statistiques
    │   │   ├── menu/             # Gérer menu
    │   │   └── profile/
    │   └── main.dart
    └── pubspec.yaml
```

## 🚀 Utilisation Rapide

### Dans les deux applications

```dart
// 1. Importer le package
import 'package:shared_core/shared_core.dart';

// 2. Utiliser les entités communes
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

// 3. Utiliser les constantes
final apiUrl = ApiConstants.baseUrl; // "https://api.wintime.com/v1"

// 4. Utiliser les utilitaires
final dateStr = DateFormatter.formatRelative(order.createdAt);
// "Il y a 15 minutes"

// 5. Utiliser ApiResult
ApiResult<OrderEntity> result = await repository.getOrder(id);
result.when(
  onSuccess: (order) => print('Success: ${order.orderNumber}'),
  onFailure: (failure) => print('Error: ${failure.message}'),
);
```

## 🔄 Migration Depuis le Code Existant

### Étape 1 : Importer shared_core

Remplacez les imports locaux par l'import du package :

**Avant :**
```dart
import '../domain/entities/order_entity.dart';
import '../domain/entities/user_entity.dart';
import '../../core/errors/failures.dart';
```

**Après :**
```dart
import 'package:shared_core/shared_core.dart';
```

### Étape 2 : Supprimer les doublons

Supprimez les fichiers dupliqués dans chaque app :
- `lib/features/*/domain/entities/order_entity.dart` → Utiliser shared_core
- `lib/features/*/domain/entities/user_entity.dart` → Utiliser shared_core
- `lib/core/constants/api_constants.dart` → Utiliser shared_core

### Étape 3 : Adapter si nécessaire

Si une app a besoin de fonctionnalités spécifiques, créez une extension :

```dart
// Dans l'app Pro uniquement
extension OrderEntityProExtension on OrderEntity {
  bool get needsUrgentAttention =>
    status == OrderStatus.pending &&
    DateTime.now().difference(createdAt).inMinutes > 5;
}
```

## 📊 Répartition du Code

| Composant | Emplacement | Pourcentage |
|-----------|-------------|-------------|
| Entités communes | `shared_core` | 15% |
| Enums et constantes | `shared_core` | 10% |
| Utilitaires | `shared_core` | 10% |
| Gestion d'erreurs | `shared_core` | 5% |
| **Total Partagé** | **shared_core** | **~40%** |
| Features spécifiques client | `win_time` | 30% |
| Features spécifiques restaurant | `win_time_pro` | 30% |

## 🎨 Différences Entre les Apps

### Win Time (Client) - Fonctionnalités Spécifiques
- Découverte de restaurants (Maps, géolocalisation)
- Recherche et filtres
- Paiement en ligne (Stripe)
- Historique de commandes client
- Notation des restaurants

### Win Time Pro (Restaurant) - Fonctionnalités Spécifiques
- Dashboard en temps réel
- Gestion des commandes entrantes
- Statistiques et analytics
- Gestion du menu/catalogue
- Configuration restaurant

## 🔧 Maintenance

### Ajouter une nouvelle entité commune

1. Créez le fichier dans `packages/shared_core/lib/src/domain/entities/`
2. Ajoutez l'export dans `packages/shared_core/lib/shared_core.dart`
3. Exécutez `flutter pub get` dans les deux apps
4. Utilisez-la dans les deux applications

### Modifier une entité existante

1. Modifiez le fichier dans `shared_core`
2. Testez les deux applications
3. Committez les changements

### Ajouter un utilitaire commun

1. Créez le fichier dans `packages/shared_core/lib/src/core/utils/`
2. Ajoutez l'export dans `shared_core.dart`
3. Documentez dans le README du package

## ✅ Checklist de Compatibilité

Avant de merger une modification dans `shared_core`, vérifiez :

- [ ] Le changement est pertinent pour **les deux applications**
- [ ] Les tests passent dans les deux apps
- [ ] La documentation est à jour
- [ ] Pas de breaking change (ou version bump si nécessaire)
- [ ] Les dépendances sont compatibles avec les deux apps

## 🐛 Résolution de Problèmes

### Erreur : "Package not found"

```bash
cd packages/shared_core
flutter pub get

cd ../../win_time_mobilapp\ copie
flutter pub get

cd ../win_time_pro_mobilapp\ copie
flutter pub get
```

### Conflits de versions

Si vous avez des conflits de dépendances, ajustez les contraintes de version dans `packages/shared_core/pubspec.yaml` pour qu'elles soient compatibles avec les deux apps.

### Import ne fonctionne pas

Assurez-vous que :
1. Le package est bien ajouté dans `pubspec.yaml`
2. Vous avez exécuté `flutter pub get`
3. L'import est : `import 'package:shared_core/shared_core.dart';`

## 📚 Ressources

- [README du package shared_core](packages/shared_core/README.md)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Package Development](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)

---

**Questions ?** Consultez la documentation du package ou contactez l'équipe technique.
