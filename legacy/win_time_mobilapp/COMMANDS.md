# Commandes Utiles - Win Time

## 🚀 Démarrage Rapide

### Installation initiale

```bash
# 1. Récupérer les dépendances
flutter pub get

# 2. Générer le code (models, DI, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Générer l'icône de l'app
flutter pub run flutter_launcher_icons

# 4. Vérifier l'installation
flutter doctor -v
```

## 🔧 Développement

### Lancer l'application

```bash
# Mode debug (avec hot reload)
flutter run

# Mode debug sur un device spécifique
flutter run -d <device_id>

# Lister les devices disponibles
flutter devices

# Mode release (optimisé)
flutter run --release

# Mode profile (pour analyser les performances)
flutter run --profile
```

### Code Generation

```bash
# Générer tout le code
flutter pub run build_runner build --delete-conflating-outputs

# Watch mode (regénère automatiquement)
flutter pub run build_runner watch

# Nettoyer et regénérer
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Analyse et Qualité

```bash
# Analyser le code (linting)
flutter analyze

# Formater le code
flutter format .

# Formater un fichier spécifique
flutter format lib/main.dart

# Vérifier les imports inutilisés
dart analyze

# Pub outdated (packages à mettre à jour)
flutter pub outdated
```

## 🧪 Tests

### Exécuter les tests

```bash
# Tous les tests
flutter test

# Tests avec coverage
flutter test --coverage

# Tests d'un fichier spécifique
flutter test test/features/orders/orders_bloc_test.dart

# Tests avec rapport détaillé
flutter test --reporter expanded

# Tests d'intégration
flutter test integration_test/
```

### Coverage HTML

```bash
# Générer le rapport HTML
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Ouvrir le rapport
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
start coverage/html/index.html  # Windows
```

## 📦 Build Production

### Android

```bash
# APK (pour test)
flutter build apk --release

# APK split par ABI (plus petit)
flutter build apk --split-per-abi

# App Bundle (pour Play Store)
flutter build appbundle --release

# APK avec obfuscation
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

### iOS

```bash
# Build iOS
flutter build ios --release

# Générer IPA
flutter build ipa --release

# Sans codesign (pour tester)
flutter build ios --release --no-codesign
```

### Web

```bash
# Build web
flutter build web --release

# Web avec canvas (meilleure performance)
flutter build web --web-renderer canvaskit

# Web avec HTML (plus petit)
flutter build web --web-renderer html
```

## 🔍 Debug

### Logs

```bash
# Afficher tous les logs
flutter logs

# Logs d'un device spécifique
flutter logs -d <device_id>

# Logs avec filtre
flutter logs | grep "ERROR"
```

### DevTools

```bash
# Ouvrir DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Ou via VSCode
# Cmd/Ctrl + Shift + P → "Flutter: Open DevTools"
```

### Performance

```bash
# Profile mode
flutter run --profile

# Mesurer la taille de l'app
flutter build apk --analyze-size
flutter build ios --analyze-size

# Timeline trace
flutter run --profile --trace-startup
```

## 🧹 Nettoyage

### Clean

```bash
# Nettoyer le build
flutter clean

# Nettoyer + récupérer les dépendances
flutter clean && flutter pub get

# Nettoyer completement (iOS)
flutter clean
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..

# Nettoyer completement (Android)
flutter clean
cd android && ./gradlew clean && cd ..
```

### Cache

```bash
# Nettoyer le cache pub
flutter pub cache clean

# Réparer le cache
flutter pub cache repair
```

## 📱 Devices

### Émulateurs

```bash
# Lister les émulateurs
flutter emulators

# Lancer un émulateur
flutter emulators --launch <emulator_id>

# Créer un émulateur Android
flutter emulators --create

# iOS Simulator
open -a Simulator
```

### Devices physiques

```bash
# Lister les devices connectés
flutter devices

# Informations détaillées
flutter devices -v

# Android ADB
adb devices
adb logcat

# iOS
instruments -s devices
```

## 🔐 Signing (Production)

### Android

```bash
# Générer keystore
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Vérifier le keystore
keytool -list -v -keystore ~/upload-keystore.jks
```

Puis configurer dans `android/key.properties` :
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

### iOS

Via Xcode :
1. Ouvrir `ios/Runner.xcworkspace`
2. Signer & Capabilities
3. Sélectionner l'équipe
4. Archive → Upload to App Store

## 🚢 Déploiement

### Play Store (Android)

```bash
# Build app bundle
flutter build appbundle --release

# Fichier généré
# build/app/outputs/bundle/release/app-release.aab
```

Puis upload sur [Play Console](https://play.google.com/console)

### App Store (iOS)

```bash
# Build IPA
flutter build ipa --release

# Fichier généré
# build/ios/ipa/*.ipa
```

Puis upload via Xcode ou Transporter

## 🔄 Mise à jour

### Flutter

```bash
# Mettre à jour Flutter
flutter upgrade

# Vérifier la version
flutter --version

# Changer de channel
flutter channel stable
flutter channel beta
```

### Packages

```bash
# Mettre à jour tous les packages
flutter pub upgrade

# Mettre à jour un package spécifique
flutter pub upgrade <package_name>

# Maj majeure (pubspec.yaml)
flutter pub upgrade --major-versions
```

## 🐛 Troubleshooting

### Problèmes fréquents

```bash
# "No Firebase App"
cd ios && pod install && cd ..
flutter clean && flutter pub get

# "Gradle build failed"
cd android && ./gradlew clean && cd ..
flutter clean && flutter pub get

# "CocoaPods not installed"
sudo gem install cocoapods
pod setup

# "Build runner not generating"
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs

# "License not accepted" (Android)
flutter doctor --android-licenses

# "Xcode command line tools"
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

## 📊 Benchmarks

### Mesurer les performances

```bash
# Startup time
flutter run --profile --trace-startup

# Dump SKP (Skia Picture)
flutter screenshot --type=skp

# Memory snapshot
flutter run --profile
# Puis dans DevTools → Memory

# CPU profiling
flutter run --profile
# Puis dans DevTools → CPU Profiler
```

## 🔧 Outils Utiles

### Global packages recommandés

```bash
# DevTools
flutter pub global activate devtools

# FVM (Flutter Version Management)
dart pub global activate fvm

# Dart Code Metrics
flutter pub global activate dart_code_metrics

# Melos (mono-repo)
dart pub global activate melos
```

## 📝 Scripts Personnalisés

Créer `scripts/run.sh` :

```bash
#!/bin/bash

# Nettoyer et démarrer
clean_run() {
    flutter clean
    flutter pub get
    flutter pub run build_runner build --delete-conflicting-outputs
    flutter run
}

# Tests avec coverage
test_coverage() {
    flutter test --coverage
    genhtml coverage/lcov.info -o coverage/html
    open coverage/html/index.html
}

# Build complet
build_all() {
    flutter build apk --release
    flutter build appbundle --release
    flutter build ios --release
}

# Exécuter selon l'argument
case "$1" in
    "clean") clean_run ;;
    "test") test_coverage ;;
    "build") build_all ;;
    *) echo "Usage: ./run.sh {clean|test|build}" ;;
esac
```

Utilisation :
```bash
chmod +x scripts/run.sh
./scripts/run.sh clean
```

## 📚 Ressources

- [Flutter CLI Reference](https://docs.flutter.dev/reference/flutter-cli)
- [Dart CLI Reference](https://dart.dev/tools/dart-tool)
- [Build Runner](https://pub.dev/packages/build_runner)
