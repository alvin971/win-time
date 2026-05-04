# Setup Firebase — Win Time

Ce doc liste les **actions hors-IDE** nécessaires pour rendre la démo end-to-end opérationnelle. Tout le code applicatif (entités, mappers, util geohash, rules, indexes, seed fixtures) est déjà en place. Il manque uniquement les **secrets** et la **création du projet Firebase**.

---

## 1. Créer le projet Firebase

Depuis [console.firebase.google.com](https://console.firebase.google.com) :

1. **Add project** → nom `wintime-demo` (ou autre, mais alors mettre à jour `.firebaserc`).
2. **Plan Spark** suffit pour la démo (Firestore + Auth + Storage gratuits jusqu'à des quotas confortables).
3. Activer dans "Build" :
   - **Authentication** → Sign-in method → activer **Email/Password** ET **Anonymous**.
   - **Firestore Database** → Create database → région **`europe-west1`** (Belgique) → mode **production** (les rules qu'on déploie ensuite sont strictes).
   - **Storage** → Get started → même région **`europe-west1`** → mode production.
   - **Cloud Messaging** : déjà câblé côté code (FCM) — rien à activer côté console.

---

## 2. Enregistrer les apps mobiles dans le projet

Dans Project settings → "Your apps", ajouter **4 apps** :

| Plateforme | Bundle / Package ID | App | Action |
|------------|---------------------|-----|--------|
| iOS | `0for0.com` | Win Time Client | Add app → télécharger `GoogleService-Info.plist` |
| iOS | `com.mycompany.louppartner3` | Win Time Pro | Add app → télécharger `GoogleService-Info.plist` |
| Android | (voir `android/app/build.gradle.kts` du Client) | Win Time Client | Add app → télécharger `google-services.json` |
| Android | (voir `android/app/build.gradle.kts` du Pro) | Win Time Pro | Add app → télécharger `google-services.json` |

Pour récupérer les `applicationId` Android :
```bash
grep -r "applicationId" win_time_mobilapp/android/app/build.gradle.kts win_time_pro_mobilapp/android/app/build.gradle.kts
```

---

## 3. Lancer FlutterFire CLI sur chaque app

Une fois les 4 apps enregistrées dans le projet Firebase :

```bash
# Installer FlutterFire CLI (une fois globalement)
dart pub global activate flutterfire_cli

# Client
cd /home/ubuntu/win-time/win_time_mobilapp
flutterfire configure --project=wintime-demo

# Pro
cd /home/ubuntu/win-time/win_time_pro_mobilapp
flutterfire configure --project=wintime-demo
```

Pour CHAQUE app, l'outil va :
- Générer `lib/firebase_options.dart` (à committer — pas un secret)
- Placer `ios/Runner/GoogleService-Info.plist` au bon endroit (gitignored par défaut, à inclure dans le commit selon convention équipe)
- Placer `android/app/google-services.json` (idem)
- Ajouter le plugin `com.google.gms:google-services` aux `build.gradle.kts` Android

---

## 4. Patcher `main.dart` des deux apps

Une fois `firebase_options.dart` généré, modifier dans **les deux mains** :

```dart
// Avant
await Firebase.initializeApp().timeout(const Duration(seconds: 5));

// Après
import 'firebase_options.dart';
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
).timeout(const Duration(seconds: 5));
```

**Garder le `try/catch` + timeout** existant — c'est défensif et utile.

---

## 5. iOS Info.plist — descriptions privacy

Pour le **Pro** uniquement (Client a déjà ce qu'il faut), ajouter dans `win_time_pro_mobilapp/ios/Runner/Info.plist` :

```xml
<key>NSCameraUsageDescription</key>
<string>Win Time Pro utilise la caméra pour ajouter des photos de votre menu et de votre restaurant.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Win Time Pro utilise votre galerie photo pour importer les images de votre menu et de votre restaurant.</string>
```

---

## 6. Déployer rules + indexes

Depuis la racine `/home/ubuntu/win-time/` :

```bash
# Une fois
npm install -g firebase-tools  # si pas déjà fait
firebase login
firebase use wintime-demo

# Déploiement
firebase deploy --only firestore:rules,firestore:indexes,storage
```

---

## 7. Seed des données démo

Télécharger le **service account JSON** :
- Console Firebase → Project Settings → Service Accounts → Generate new private key
- Sauvegarder dans `scripts/service-account.json`
- **NE PAS COMMITTER** ce fichier (il contient une clé privée)

Lancer le seed :
```bash
cd /home/ubuntu/win-time
./scripts/seed_demo.sh
```

Ça va créer :
- 5 comptes Firebase Auth (4 demo Pro + 1 demo customer + 3 owners restaurants), tous avec le password `demo-pass-1234`
- 5 docs `/users/{uid}`
- 4 docs `/restaurants/{rid}` (Trattoria, Bistrot du Louvre, Sakura Sushi, Beirut Étoile)
- 14 catégories + 25 produits dans les sous-collections menu

Idempotent : peut être relancé sans casser quoi que ce soit.

---

## 8. .gitignore à mettre à jour

Ajouter à `/home/ubuntu/win-time/.gitignore` (s'ils n'y sont pas déjà) :

```gitignore
# Firebase secrets
scripts/service-account.json
scripts/node_modules/
**/.firebase/

# FlutterFire generated configs (selon convention équipe)
# - firebase_options.dart : OK à committer (pas de secret)
# - GoogleService-Info.plist : à débattre (souvent committé pour CI)
# - google-services.json : à débattre (souvent committé pour CI)
```

---

## 9. Vérification rapide

### Émulateur Firestore (test sans toucher au cloud)

```bash
cd /home/ubuntu/win-time
firebase emulators:start --only firestore,auth,storage
# → ouvre http://localhost:4000 (UI émulateur)
```

### Vérifier un build Flutter

```bash
cd packages/shared_core && flutter pub get && dart analyze
cd ../../win_time_pro_mobilapp && flutter pub get && cd ios && pod install && cd ..
cd ../win_time_mobilapp && flutter pub get && cd ios && pod install && cd ..
```

Les 2 apps doivent compiler. Le code Flutter Firestore (datasources/BLoCs/pages) sera ajouté lors des prochaines sessions, mais le socle (entités, mappers, repos abstraits, util geohash) est déjà fonctionnel et type-safe.

---

## 10. Récap des comptes de démo

| Compte | App | Rôle | UID | Password |
|--------|-----|------|-----|----------|
| `owner.demo@wintime.test` | Pro | restaurantOwner | `demo-owner-001` | `demo-pass-1234` |
| `manager.demo@wintime.test` | Pro | restaurantManager | `demo-manager-001` | `demo-pass-1234` |
| `staff.demo@wintime.test` | Pro | restaurantStaff | `demo-staff-001` | `demo-pass-1234` |
| `admin.demo@wintime.test` | Pro | admin | `demo-admin-001` | `demo-pass-1234` |
| `demo.customer@wintime.test` | Client | client | `demo-customer-001` | `demo-pass-1234` |

`owner.demo@wintime.test` est propriétaire de **La Trattoria du Châtelet**. Les 3 autres restaurants ont des propriétaires distincts (`owner-fr-002`, `owner-jp-003`, `owner-lb-004`) pour démontrer le multi-tenant.
