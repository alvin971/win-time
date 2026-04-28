# 🚀 Guide de Démarrage - Win Time Pro

## Prérequis

### Outils requis
- Flutter SDK 3.8.1 ou supérieur
- Dart SDK 3.8.1 ou supérieur
- Android Studio / VS Code avec extensions Flutter
- Xcode (pour iOS, macOS uniquement)
- Git

### Vérification de l'installation
```bash
flutter doctor -v
```

---

## 📥 Installation

### 1. Cloner le projet
```bash
git clone https://github.com/votre-org/win-time-pro.git
cd win-time-pro
```

### 2. Installer les dépendances
```bash
flutter pub get
```

### 3. Générer le code (si nécessaire)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Configuration Firebase (optionnel pour le MVP)

#### Android
1. Télécharger `google-services.json` depuis Firebase Console
2. Placer dans `android/app/`

#### iOS
1. Télécharger `GoogleService-Info.plist` depuis Firebase Console
2. Placer dans `ios/Runner/`

---

## 🏃 Lancer l'application

### Mode Debug
```bash
# Lister les appareils disponibles
flutter devices

# Lancer sur l'appareil par défaut
flutter run

# Lancer sur un appareil spécifique
flutter run -d <device-id>

# Exemple: lancer sur Chrome
flutter run -d chrome

# Exemple: lancer sur émulateur Android
flutter run -d emulator-5554
```

### Mode Release
```bash
flutter run --release
```

---

## 🔧 Configuration

### Variables d'environnement

Créer un fichier `.env` à la racine :
```env
API_BASE_URL=https://api.wintimepro.com/v1
API_TIMEOUT=30000
FIREBASE_API_KEY=your_api_key
```

### Configuration API

Modifier `lib/core/constants/api_constants.dart` :
```dart
static const String baseUrl = 'https://api.wintimepro.com/v1';
```

---

## 📂 Structure du Projet

```
lib/
├── core/                   # Code partagé
│   ├── constants/          # Constantes
│   ├── errors/             # Gestion erreurs
│   ├── network/            # Configuration réseau
│   ├── theme/              # Design system
│   └── widgets/            # Widgets globaux
│
├── features/               # Fonctionnalités
│   ├── auth/               # Authentification
│   ├── dashboard/          # Tableau de bord
│   ├── orders/             # Commandes
│   ├── menu/               # Menu/Produits
│   ├── profile/            # Profil restaurant
│   └── statistics/         # Statistiques
│
└── main.dart               # Point d'entrée
```

Chaque feature suit Clean Architecture :
```
feature_name/
├── data/
│   ├── models/             # DTOs
│   ├── repositories/       # Implémentation
│   └── datasources/        # API/Local
├── domain/
│   ├── entities/           # Objets métier
│   ├── repositories/       # Interfaces
│   └── usecases/           # Business logic
└── presentation/
    ├── bloc/               # State management
    ├── pages/              # Écrans
    └── widgets/            # Widgets locaux
```

---

## 🧪 Tests

### Exécuter tous les tests
```bash
flutter test
```

### Tests avec coverage
```bash
flutter test --coverage
lcov --list coverage/lcov.info
```

### Tests d'un fichier spécifique
```bash
flutter test test/features/auth/domain/usecases/login_usecase_test.dart
```

---

## 🏗️ Build

### Android

#### APK Debug
```bash
flutter build apk --debug
```

#### APK Release
```bash
flutter build apk --release
```

#### App Bundle (Google Play)
```bash
flutter build appbundle --release
```

Les fichiers générés se trouvent dans `build/app/outputs/`

### iOS

```bash
# Ouvrir Xcode
open ios/Runner.xcworkspace

# Ou build en ligne de commande
flutter build ios --release
```

### Web

```bash
flutter build web --release
```

Les fichiers générés se trouvent dans `build/web/`

---

## 🎨 Personnalisation du Thème

### Modifier les couleurs principales

Éditer `lib/core/theme/app_colors.dart` :
```dart
static const Color primary = Color(0xFF2563EB);    // Bleu
static const Color secondary = Color(0xFF10B981);  // Vert
```

### Modifier la police

Éditer `lib/core/theme/app_theme.dart` :
```dart
textTheme: GoogleFonts.robotoTextTheme()  // Changer Poppins par Roboto
```

---

## 📱 Ajout d'une nouvelle feature

### 1. Créer la structure
```bash
mkdir -p lib/features/ma_feature/{data/{models,repositories,datasources},domain/{entities,repositories,usecases},presentation/{bloc,pages,widgets}}
```

### 2. Créer l'entité (Domain)
```dart
// lib/features/ma_feature/domain/entities/mon_entity.dart
import 'package:equatable/equatable.dart';

class MonEntity extends Equatable {
  final String id;
  final String name;

  const MonEntity({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
```

### 3. Créer le repository interface (Domain)
```dart
// lib/features/ma_feature/domain/repositories/mon_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/mon_entity.dart';

abstract class MonRepository {
  Future<Either<Failure, List<MonEntity>>> getAll();
  Future<Either<Failure, MonEntity>> getById(String id);
}
```

### 4. Créer le BLoC (Presentation)
```dart
// lib/features/ma_feature/presentation/bloc/mon_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'mon_event.dart';
import 'mon_state.dart';

class MonBloc extends Bloc<MonEvent, MonState> {
  MonBloc() : super(const MonInitial()) {
    on<MonLoadRequested>(_onLoadRequested);
  }

  Future<void> _onLoadRequested(
    MonLoadRequested event,
    Emitter<MonState> emit,
  ) async {
    emit(const MonLoading());
    // Logique...
  }
}
```

### 5. Créer la page (Presentation)
```dart
// lib/features/ma_feature/presentation/pages/mon_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MonPage extends StatelessWidget {
  const MonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MonBloc()..add(const MonLoadRequested()),
      child: const MonView(),
    );
  }
}

class MonView extends StatelessWidget {
  const MonView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ma Feature')),
      body: BlocBuilder<MonBloc, MonState>(
        builder: (context, state) {
          if (state is MonLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MonLoaded) {
            return ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(state.items[index].name));
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
```

---

## 🐛 Debugging

### Afficher les logs
```bash
# Logs en temps réel
flutter logs

# Logs filtrés
flutter logs | grep "MyTag"
```

### Analyser les performances
```bash
# Activer DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Puis dans l'app
flutter run --profile
```

### Activer le mode verbose
```bash
flutter run -v
```

---

## 🔑 Raccourcis Utiles

### Dans l'IDE
- `Ctrl+Space` : Autocomplétion
- `Ctrl+Shift+F` : Formater le code
- `F5` : Lancer en debug
- `Shift+F5` : Arrêter

### En cours d'exécution (dans le terminal)
- `r` : Hot reload
- `R` : Hot restart
- `q` : Quitter
- `p` : Afficher la grille de debug
- `o` : Basculer plateforme (Android/iOS)

---

## 📚 Ressources Utiles

### Documentation
- [Flutter Docs](https://docs.flutter.dev/)
- [Dart Docs](https://dart.dev/guides)
- [BLoC Library](https://bloclibrary.dev/)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

### Extensions VS Code recommandées
- Flutter
- Dart
- Bloc
- Error Lens
- GitLens
- TODO Highlight

### Extensions Android Studio recommandées
- Flutter
- Dart
- Rainbow Brackets

---

## ❓ FAQ

### L'app ne compile pas
```bash
# Nettoyer le projet
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Erreur "No Firebase App"
Vérifier que `google-services.json` et `GoogleService-Info.plist` sont bien placés et que Firebase est initialisé dans `main.dart`.

### Hot reload ne fonctionne pas
Redémarrer avec `R` dans le terminal, ou relancer complètement l'app.

### Problème de dépendances
```bash
flutter pub upgrade
flutter pub get
```

---

## 🤝 Contribution

### Convention de commits
```
feat: Nouvelle fonctionnalité
fix: Correction de bug
refactor: Refactoring
docs: Documentation
test: Tests
chore: Tâches diverses
```

### Workflow
1. Créer une branche `feature/nom-feature`
2. Développer et tester
3. Commit avec message conventionnel
4. Push et créer une Pull Request
5. Code review
6. Merge dans `develop`

---

## 📞 Support

- Documentation: `README_ARCHITECTURE.md`
- Issues: GitHub Issues
- Email: support@wintimepro.com

---

Bon développement ! 🚀
