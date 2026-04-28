# Guide de Configuration - Win Time

## 📋 Prérequis

### Outils nécessaires
- Flutter SDK 3.5.0+
- Dart SDK 3.5.0+
- Android Studio / Xcode
- VS Code (recommandé) avec extensions Flutter
- Git
- Compte Firebase
- Compte Stripe (mode test pour développement)

### Vérification

```bash
flutter doctor -v
```

Tous les éléments doivent être ✓ (checkés).

## 🔧 Configuration Détaillée

### 1. Firebase Setup

#### Étape 1 : Créer le projet Firebase
1. Aller sur [Firebase Console](https://console.firebase.google.com)
2. Créer un nouveau projet "Win Time"
3. Activer Google Analytics (optionnel)

#### Étape 2 : Ajouter l'app Android
1. Dans Firebase Console → Ajouter une app → Android
2. Package name : `com.wintime.app` (à adapter)
3. Télécharger `google-services.json`
4. Placer dans `android/app/`

#### Étape 3 : Ajouter l'app iOS
1. Dans Firebase Console → Ajouter une app → iOS
2. Bundle ID : `com.wintime.app` (à adapter)
3. Télécharger `GoogleService-Info.plist`
4. Placer dans `ios/Runner/`

#### Étape 4 : Activer les services Firebase

##### Cloud Firestore
```
Firebase Console → Build → Firestore Database → Créer
Mode : Production (ou Test pour développement)
Région : europe-west1 (recommandé pour l'Europe)
```

##### Cloud Messaging (Push Notifications)
```
Firebase Console → Build → Cloud Messaging
Télécharger la clé serveur pour le backend
```

##### Analytics (optionnel)
```
Firebase Console → Analytics → Activer
```

### 2. Configuration Android

#### Fichier `android/app/build.gradle`

```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.wintime.app"
        minSdkVersion 24
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }
}

dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.4.0'
    implementation 'com.android.support:multidex:1.0.3'
}
```

#### Fichier `android/build.gradle`

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

#### Fichier `android/app/build.gradle` (fin)

```gradle
apply plugin: 'com.google.gms.google-services'
```

#### Fichier `android/app/src/main/AndroidManifest.xml`

```xml
<manifest>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

    <application
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- Notifications -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/notification_color" />
    </application>
</manifest>
```

### 3. Configuration iOS

#### Fichier `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Nous avons besoin de votre position pour trouver les restaurants à proximité</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Nous avons besoin de votre position pour améliorer votre expérience</string>

<key>NSCameraUsageDescription</key>
<string>Nous avons besoin d'accéder à votre caméra pour scanner les QR codes</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Nous avons besoin d'accéder à vos photos pour télécharger une image</string>
```

#### Push Notifications (iOS)

1. Ouvrir Xcode : `open ios/Runner.xcworkspace`
2. Sélectionner le projet Runner
3. Signing & Capabilities → + Capability
4. Ajouter "Push Notifications"
5. Ajouter "Background Modes" → cocher "Remote notifications"

#### Apple Maps API Key

1. Aller sur [Apple Developer Console](https://developer.apple.com)
2. Créer une clé pour Maps
3. Ajouter dans `Info.plist` :

```xml
<key>GoogleMapsAPIKey</key>
<string>YOUR_IOS_MAPS_KEY</string>
```

### 4. Configuration Google Maps

#### Android

Fichier `android/app/src/main/AndroidManifest.xml` :

```xml
<application>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_ANDROID_MAPS_KEY"/>
</application>
```

#### iOS

Déjà configuré dans Info.plist (voir section iOS).

### 5. Configuration Stripe

#### Mode Test

Dans `lib/core/config/app_config.dart` :

```dart
static const String stripePublishableKey = 'pk_test_YOUR_TEST_KEY';
```

#### Backend

Le backend doit avoir la clé secrète Stripe :
```
STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
```

### 6. Variables d'Environnement

Créer un fichier `.env` à la racine :

```env
API_BASE_URL=https://api.wintime.com/v1
WS_BASE_URL=wss://ws.wintime.com
STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY
GOOGLE_MAPS_API_KEY_ANDROID=YOUR_ANDROID_KEY
GOOGLE_MAPS_API_KEY_IOS=YOUR_IOS_KEY
```

**Important** : Ajouter `.env` au `.gitignore` !

### 7. Code Generation

Lancer la génération de code pour :
- Dependency Injection (injectable)
- JSON Serialization (json_serializable)
- Retrofit (API client)
- Hive (TypeAdapters)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 8. Assets

#### Images

Placer les images dans :
```
assets/images/
├── logo.png
├── placeholder_restaurant.png
└── ...
```

#### Polices

Télécharger Inter font depuis [Google Fonts](https://fonts.google.com/specimen/Inter)

Placer dans :
```
fonts/
├── Inter-Regular.ttf
├── Inter-Medium.ttf
├── Inter-SemiBold.ttf
└── Inter-Bold.ttf
```

#### App Icon

Placer l'icône dans `assets/icons/app_icon.png` (1024x1024)

Générer :
```bash
flutter pub run flutter_launcher_icons
```

## 🧪 Vérification

### 1. Lancer les tests

```bash
flutter test
```

### 2. Analyser le code

```bash
flutter analyze
```

### 3. Vérifier le format

```bash
flutter format .
```

### 4. Lancer l'app

```bash
# Android
flutter run -d <device_id>

# iOS
flutter run -d <device_id>
```

## 🐛 Résolution de Problèmes

### Problème : "No Firebase App"

**Solution** :
```bash
cd ios && pod install && cd ..
flutter clean
flutter pub get
```

### Problème : "Gradle build failed"

**Solution** :
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Problème : "CocoaPods not installed"

**Solution** :
```bash
sudo gem install cocoapods
pod setup
```

### Problème : Build Runner ne génère pas

**Solution** :
```bash
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📝 Checklist Finale

- [ ] Firebase configuré (Android + iOS)
- [ ] Google Maps API activée
- [ ] Stripe configuré (mode test)
- [ ] Code généré (build_runner)
- [ ] Assets placés
- [ ] App icon généré
- [ ] Tests passent
- [ ] Analyze OK
- [ ] App lance sans erreur

## 🚀 Prochaines Étapes

1. Implémenter l'authentification complète
2. Connecter au backend API
3. Tester les notifications push
4. Tester les paiements Stripe
5. Tests utilisateurs

## 📞 Support

En cas de problème, contactez l'équipe technique :
- Slack : #win-time-dev
- Email : dev@wintime.com
