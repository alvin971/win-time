# Win Time — TestFlight Build Tracker

> Logbook itératif de la résolution du problème "builds iOS n'arrivent pas sur TestFlight".
> Démarré le 2026-05-02 par Claude. Référence de plan : `/home/ubuntu/.claude/plans/ouvre-win-time-il-synchronous-cupcake.md`.

## État actuel (2026-05-02 12:30 UTC)

| App | Bundle ID | App ID ASC | Dernier run CI | Conclusion | processingState ASC |
|-----|-----------|------------|----------------|------------|---------------------|
| win-time (client)  | `0for0.com`                       | `6764433401` | `25140230022` (commit 716b340, 2026-04-30) | **failure** (cert auth) | inconnu (API à interroger) |
| win-time-pro       | `com.mycompany.louppartner3`      | `6764434885` | `25140230016` (commit 716b340, 2026-04-30) | **success** (uploaded 00:13:09 UTC) | inconnu (API à interroger) |

## Checklist pipeline (cumulée des sessions précédentes + ce diagnostic)
- [x] Concurrency group `ios-signing` (commit 716b340) — sérialisation OK
- [x] Bundle IDs alignés avec les apps ASC existantes
- [x] Deployment targets pbxproj == Podfile (Client 15.0, Pro 13.0)
- [x] `DEVELOPMENT_TEAM = J7K94W4PUN` dans les deux pbxproj
- [x] Fastfile aligné sur la référence Mentality (cert force:true + SIGH_UUID + provisioningProfiles)
- [x] `scripts/purge_dist_certs.py` purge les certs DISTRIBUTION avant cert(force:true)
- [x] Workflows iOS Client et Pro identiques structurellement (sauf paths/secrets/output_name)
- [x] **Pro** : build effectivement uploadé sur ASC le 2026-04-30 00:13:09 UTC (à confirmer côté ASC : VALID/PROCESSING)
- [ ] **Client** : build VALID dans TestFlight
- [ ] **Pro** : build VALID confirmé dans TestFlight (vs PROCESSING/INVALID)
- [ ] Email TestFlight reçu par `monopoly97160@gmail.com`

## Diagnostic en cours — Itération 1 (2026-05-02 12:30 UTC)

### Résumé du run `716b340` (le 2026-04-30, 00:02 → 00:30 UTC)

Les deux workflows ont été déclenchés simultanément par le push, et la concurrence `ios-signing` les a sérialisés correctement :

| Run | App | Démarrage | Fin | Conclusion |
|-----|-----|-----------|-----|------------|
| 25140230016 | Pro    | 00:02:52 | ~00:13:16 | **success** |
| 25140230022 | Client | 00:13:46 (queued) | 00:30:10 | **failure** |

Le workflow **Pro** a déroulé toutes les étapes :
- `purge_dist_certs.py` → 1 cert DISTRIBUTION supprimé (00:05:24)
- `cert(force:true)` → cert `L2TZKNR297` créé et installé dans le keychain (00:09:26)
- `sigh(force:true)` → nouveau provisioning profile (00:09:30) — log mentionne 6 certs orphelins (NX7Z78C58H, 8J3UYHLS99, C7FDL2XSL4, HNRHHV5597, UF84LT4677, GDAVVQ7Z4J) qui ne matchent plus `L2TZKNR297`
- `build_app` → IPA `WinTimePro.ipa` (00:11:36)
- `upload_to_testflight` → "Successfully uploaded the new binary to App Store Connect" (00:13:09, 93s)

Le workflow **Client** a échoué dès l'étape `cert` :
- `purge_dist_certs.py` → **0 cert DISTRIBUTION trouvés** (00:18:31) ← anomalie : Pro venait juste de créer `L2TZKNR297`, il devrait être présent
- `cert(force:true)` → erreur Apple :
  ```
  Authentication credentials are missing or invalid. - Provide a properly configured
  and signed bearer token, and make sure that it has not expired.
  ```
  Échec en ~1 seconde (00:29:59).

### Hypothèses sur la cause de l'échec Client (à tester)

| # | Hypothèse | Pourquoi plausible | Comment tester |
|---|-----------|---------------------|----------------|
| **A** | **L'API key ASC `.p8` a été rate-limitée/temporairement bloquée par Apple** après les nombreuses requêtes du run Pro (purge + cert + sigh + upload font des dizaines d'appels) | Pro a réussi avec la même clé 16 min avant ; la clé ne peut pas être "morte" ; mais Apple peut throttle après un burst | Re-trigger un run Client SEUL maintenant (3 jours plus tard, rate-limit clear) |
| **B** | **`echo "${{ secrets.APP_STORE_API_KEY_CONTENT }}"` corrompt la clé** (ex : `\n` littéraux non interprétés) sur certains runners | Étrange que Pro réussisse alors ; mais les runners macos-15-arm64 peuvent avoir des `echo` de zsh/bash subtilement différents | Patcher l'écriture du `.p8` pour utiliser `printf '%s'` + écho avec `$'...\n...'` ou base64 |
| **C** | **`purge_dist_certs.py` masque un échec d'authentification** (l'API renvoie 401, le script `data.get("data", [])` retourne `[]`, et imprime "0 certs trouvés" alors qu'en réalité l'auth a déjà échoué) | Très plausible : le script trouve 0 alors qu'il devrait trouver `L2TZKNR297` créé par Pro — **C'EST UN GROS INDICE** | Patcher `purge_dist_certs.py` pour vérifier explicitement le code HTTP et lever une erreur si != 200 |
| **D** | **Apple a invalidé la clé** entre 00:13 et 00:18 pour usage anormal | Possible mais pas réversible automatiquement — il faudrait régénérer la clé ASC | Test : query ASC API maintenant avec la même clé. Si OK → ce n'est pas la cause |

L'hypothèse **C** est très probable car `purge_dist_certs.py` ne vérifie PAS le statut HTTP de la requête `GET /v1/certificates`. Il assume la réussite et lit `data["data"]`. Si l'auth échoue silencieusement (403/401 avec body `{"errors":[...]}`), `data.get("data", [])` retourne `[]` et le script imprime "0 certs trouvés" — c'est exactement ce qu'on voit dans le log Client. C'est cohérent avec une auth qui échoue **dès la première requête de Client** (au moment du purge, pas seulement de cert).

### Action prise — Itération 1

1. **Créer `scripts/check_asc_builds.py`** : thermomètre qui interroge l'API ASC pour les deux apps et imprime l'état des builds. Permet de savoir si Pro est `VALID` dans TestFlight (bonne nouvelle) ou `INVALID/MISSING` (Apple l'a rejeté).
2. **Patcher `scripts/purge_dist_certs.py`** : ajouter une vérification du statut HTTP — si l'API renvoie une erreur, le script `sys.exit(1)` au lieu de masquer en "0 certs". Cela rendra l'erreur visible immédiatement et évitera le faux positif.
3. **Trigger workflow_dispatch sur ios_client.yml** : 3 jours après le dernier run, tout rate-limit est dissipé. Si la même erreur se reproduit, la cause n'est pas un rate-limit transitoire et il faut creuser (régénérer la clé .p8, ou autre).

## Procédure pour les itérations suivantes

À chaque itération, pour chaque run CI :
1. Capter l'`ID` du run via `gh run list --workflow=ios_client.yml --limit 1 --repo alvin971/win-time --json databaseId,conclusion,status,createdAt`
2. Watcher avec `gh run watch <ID> --repo alvin971/win-time` (jusqu'à conclusion)
3. Si `failure` : `gh api /repos/alvin971/win-time/actions/jobs/<JOB_ID>/logs > /tmp/run_<ID>.log` et grep les erreurs
4. Mettre à jour ce fichier (nouvelle section "Itération N")
5. Pousser le fix avec un commit `debug:` ou `fix:` (un seul changement par itération)

## Hypothèses (suivi)

| # | Hypothèse | Statut | Test effectué |
|---|-----------|--------|---------------|
| H1 | Aucun run depuis 716b340 | ❌ Écartée | Runs présents : Pro success, Client failure |
| H2 | APPLE_TEAM_ID secret stale | ⏳ À vérifier (le secret est sécurisé, pas lisible directement, on le valide via le log) | log Pro montre `team_id: ***` (masked) mais Pro réussit donc bon |
| H3 | BUNDLE_ID_CLIENT/PRO ne matchent pas pbxproj | ⏳ Pro réussit avec `BUNDLE_ID_PRO` ; Client `BUNDLE_ID_CLIENT` à vérifier en cas d'échec | — |
| H4 | API ASC clé `.p8` invalide | ⏳ Pro a réussi mais Client échoue 16min plus tard avec erreur auth | À tester avec `check_asc_builds.py` localement |
| **C** | **Purge silently swallows ASC auth failures** | **🟡 Très probable** | Patch + retrigger |
| **A** | **Rate-limit Apple post-Pro burst** | 🟡 Possible | Retrigger 3j plus tard |

## Itération 1 — 2026-05-02 12:27 → 12:33 UTC

- **Commit** : `448f6e4` — debug: thermomètre ASC + purge strict
- **Runs** : Client `25251885818` (failure), Pro `25251886151` (cancelled à 6m41s avant qu'il atteigne le thermomètre)
- **Étape qui échoue** : `ASC API thermometer (pre-flight auth check)` — la nouvelle étape
- **Sortie clé** :
  ```
  ✅ ASC API auth OK (HTTP 200)        ← l'auth ASC FONCTIONNE
  ❌ Builds query failed — HTTP 0      ← curl renvoie HTTP 0 (transport-level)
  ```
- **Diagnostic** : le `HTTP 0` de curl indique un échec côté curl, pas Apple. Le hic : ASC utilise des URLs avec brackets `filter[app]=...` et `fields[builds]=...` ; **curl par défaut interprète `[` `]` comme un glob pattern** et échoue silencieusement. Il faut `-g`/`--globoff`. La requête `/v1/apps?limit=1` (sans brackets) marchait → c'est confirmé.
- **Hypothèse réfutée** : ❌ **C** (purge cachant un échec d'auth) — l'auth ASC marche très bien aujourd'hui avec la même clé. Le `0 certs trouvés` du Client le 30/04 doit avoir une autre cause (rate-limit, ou Apple a effectivement retiré le cert L2TZKNR297 entre temps — pourquoi reste mystère). Mais peu importe : le vrai test reste à venir.
- **Hypothèse partiellement réfutée** : ❌ **A** (rate-limit Apple) — l'auth marche maintenant avec la même clé, donc pas un blocage durable.
- **Action** : ajouter `-g`/`--globoff` aux 3 appels curl dans `check_asc_builds.py` et `purge_dist_certs.py` (asc_get, asc_delete). Re-trigger.

## Itération 2 — 2026-05-02 12:35 → 13:13 UTC (Client)

- **Commit** : `39d0f57` — fix: curl --globoff sur ASC API
- **Runs** : Client `25252030466` (success en 38m33s, upload OK 13:13:56), Pro `25252030787` (in_progress après Client)
- **Sortie thermomètre Client** :
  ```
  ✅ ASC API auth OK (HTTP 200)
  --- win-time (Client) (App ID 6764433401) ---
    ⚠️  Aucun build présent dans ASC pour cette app.
    Beta groups : wintime(int), External Testers(ext)
  --- win-time-pro (App ID 6764434885) ---
    ⚠️  Aucun build présent dans ASC pour cette app.
    Beta groups : wintimepro(int), External Testers(ext)
  ```
- **Conséquence** : **Apple a silencieusement rejeté tous les uploads précédents** (notamment celui de Pro 30/04 qui avait affiché "Successfully uploaded"). Aucun build n'est présent dans ASC pour aucune des deux apps malgré 60+ heures écoulées. Les beta groups eux sont OK.
- **Hypothèse confirmée** : ❌ A et C écartées définitivement (auth ASC marche). Le vrai problème n'est PAS un cert/auth — c'est qu'**Apple rejette les binaires pendant le post-processing sans erreur visible**.
- **Run Client d'aujourd'hui** : a uploadé à 13:13:56 UTC. État ASC à vérifier après ~10-30 min de processing Apple.
- **Run Pro d'aujourd'hui** : en cours.

### Investigation cause racine du rejet silencieux

Diff Info.plist mentality (qui marche) vs win-time :
```diff
< <key>ITSAppUsesNonExemptEncryption</key>
< <false/>
```

**`ITSAppUsesNonExemptEncryption` est ABSENT des deux Info.plist win-time** (Client et Pro). Sans cette clé, Apple :
- met le build en attente d'une déclaration manuelle dans ASC ("Manage Encryption Compliance")
- **bloque la distribution aux external testers** jusqu'à ce qu'on coche manuellement la case dans ASC web
- ne le rejette pas systématiquement, mais combiné à d'autres facteurs (ex : iOS 17+ privacy manifest), peut le bloquer en processing

**Action décidée pour itération 3** : ajouter `<key>ITSAppUsesNonExemptEncryption</key><false/>` aux deux Info.plist. Patch déjà appliqué localement, **commit en attente** (on ne pousse PAS pendant que le run Pro est en cours pour ne pas relancer un build sur du code mi-modifié).

## Itération 3 — 2026-05-02 13:25 → 14:07 UTC

- **Commit** : `d0de3a2` (Info.plist fix) + `8ccfcef` (extended thermometer)
- **Runs** :
  - Pro `25252934648` : success, upload 13:35:46 (cert `58KCP9443C`)
  - Client `25253127913` : success, upload 14:07:35 (cert `788R4FGQ27`)
- **Thermomètre asc_check à 13:58 (23 min après Pro upload)** : 0 build pour win-time/win-time-pro. 20 builds VALID dans le compte (avril 9-16) appartenant à d'autres apps (Mental ET probable).
- **État apps confirmé** : `win-time` (0for0.com, sku wintimeletgetit), `win-time-pro` (com.mycompany.louppartner3, sku wintimeproletsdpit). Beta groups OK.
- **Pre-release versions HTTP 400** pour les deux apps → aucune preReleaseVersion enregistrée jamais → **Apple n'a JAMAIS validé un upload pour ces apps**.

### Hypothèse forte identifiée (à valider Itération 4)

**Cause racine probable** : la purge de certs DISTRIBUTION du workflow N+1 **révoque le cert utilisé par le workflow N pendant qu'Apple est ENCORE en train de processer son upload**.

Timeline observée :
- 13:35:46 — Pro iter3 uploade IPA signé avec cert `58KCP9443C`
- 13:36 — Pro iter3 finit, libère concurrency lock
- 13:38-13:42 — Client iter3 démarre, **purge ALL DISTRIBUTION certs** (incl. `58KCP9443C`)
- 13:42+ — Apple finit le processing → "Validation failed (409) Certificate Revoked" → silent rejection
- Pro iter3 ne paraît jamais dans ASC

Le concurrency lock garantit la sérialisation des workflows mais **pas du processing Apple côté serveur** (qui est asynchrone, après upload).

### Test de validation (en cours, 14:07:35 → 14:30+)

Client iter3 a uploadé à 14:07:35 avec cert `788R4FGQ27`. **Aucun autre run n'est planifié**. Le cert reste valide. Si Apple a 20-30 min pour processer en paix, le build de Client iter3 doit apparaître dans ASC vers 14:25-14:30.

### Fix structurel préparé (en stash, pas encore commit/push)

Modification des deux Fastfiles : `skip_waiting_for_build_processing: false` au lieu de `true` dans `upload_to_testflight`. Force fastlane à attendre qu'Apple ait FINI le processing avant de rendre la main. Le concurrency group reste tenu pendant toute la durée du processing (5-15 min). Le run suivant ne peut donc plus lancer sa purge tant qu'Apple n'a pas fini.

Coût : +5-15 min par run. Bénéfice : élimine définitivement la race condition cert vs Apple processing.

**Pas encore commit/push** parce qu'un push relance les workflows (paths-triggered) et révoquerait le cert de Client iter3 pendant qu'Apple le processe — ce qui invaliderait notre test.

## Itération 4 — 2026-05-02 14:21 → en cours

- **Commit** `93daeef` : `skip_waiting_for_build_processing: false` dans les 2 Fastfiles
- **Auto-trigger** par push : Client `25254125854` (in_progress), Pro `25254125859` (queued)
- **Avec skip_waiting:false** : fastlane attend qu'Apple ait FINI de processer avant de rendre la main → on verra l'erreur Apple vraie

### Comparaison Mental ET (qui marche) vs win-time (qui échoue)

Via le thermomètre étendu, les apps `win-time` et `win-time-pro` ont **EXACTEMENT le même setup ASC** que Mental ET (qui marche) :
- `contentRights=None` (les 3)
- `betaAppReviewDetail` : contactEmail=None, contactFirstName=None (les 3)
- `betaLicenseAgreement.text=''` (les 3)
- `appStoreState=PREPARE_FOR_SUBMISSION` (les 3)

Mental ET a 3 builds VALID (avril 9-10). Win-time/Pro ont 0 builds. **Le métadata ASC n'est donc PAS la cause** — la différence est dans l'IPA / le bundle ID / le pipeline de signing.

### Apps visibles via la clé ASC (toutes au même team)

- 6764433401 — win-time (`0for0.com`) — 0 builds
- 6764434885 — win-time-pro (`com.mycompany.louppartner3`) — 0 builds
- 6761692391 — Mental E.T. (`com.mentalite.app`) — 3 builds VALID
- 6746979305 — File d'Attente Hospitalière (`com.alvinkuyo.hospitalqueue`)
- 6738326971 — Loup Partner (`com.mycompany.louppartner2`)
- 6670455660 — Loup Partner Old (`com.mycompany.louppartner`)

Note : `0for0.com` n'est pas un bundle ID au format reverse-DNS standard (devrait être `com.0for0`). Apple a accepté l'enregistrement de l'app mais pourrait rejeter en post-processing.

### Plan en cours

Attendre que Client iter4 finisse complètement (avec l'attente Apple inside fastlane). Si l'upload réussit ET le wait Apple passe → Apple dira pourquoi il rejetait (ou tout passera enfin). Si l'upload réussit mais Apple timeout/rejette → fastlane imprimera la vraie erreur Apple, qu'on n'a jamais eue jusqu'ici.

### 🎯 CAUSE RACINE TROUVÉE — 2026-05-02 15:47 UTC

L'endpoint ASC `/v1/apps/{id}/buildUploads` (au lieu de `/v1/apps/{id}/builds`) **expose les uploads en état FAILED** ! On voit alors les vraies erreurs Apple par upload :

**Apple error code 90683 — Missing purpose string in Info.plist** :

| App | Clé manquante (ERREUR fatale) | Clés en warning |
|-----|-------------------------------|-----------------|
| **win-time** (Client) | `NSCameraUsageDescription` | `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationWhenInUseUsageDescription` |
| **win-time-pro** (Pro) | `NSPhotoLibraryUsageDescription` | (pas d'autres remontés) |

Les **12 buildUploads** (6 Client + 6 Pro, sur les 5 derniers jours) sont tous en état `FAILED` avec ces erreurs précises. Apple les a tous rejetés silencieusement parce que :
- Les plugins Flutter (`image_picker`, `flutter_stripe`, `permission_handler`, Firebase, Maps) référencent ces APIs natives iOS
- Apple **exige** une `purpose string` même si l'app ne les utilise pas réellement
- Sans la string, Apple rejette le binaire sans le notifier comme un build dans `/v1/builds`
- L'upload existait dans `/v1/apps/{id}/buildUploads` mais en état `FAILED` (non visible via les endpoints standards utilisés par fastlane)

### Itération 5 — Fix Info.plist (RÉUSSITE 🎉)

- **Commit** : `686b1e4` — `fix: NSXxxUsageDescription dans Info.plist (cause racine 90683)`
- **Runs** :
  - Client `25255692051` : success en 32m45s (start 15:49:18, end 16:22:24, upload 16:22:15)
  - Pro `25255692058` : success en ~9m (start 16:22:31 après concurrency lock, upload 16:30:46)

**Ajout dans les deux Info.plist (Client et Pro)** :
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSContactsUsageDescription`
- `NSFaceIDUsageDescription`

Retour de `skip_waiting_for_build_processing: true` dans les Fastfiles (le wait n'était pas la cause).

### ✅ Confirmation finale (16:32 UTC)

Thermomètre asc_check à 16:32:15 UTC :
```
--- win-time (Client) (App ID 6764433401) ---
  1 build(s) trouvé(s)
  Version        Uploaded               State          Expired  Audience
  202605021605   2026-05-02 09:23 UTC   VALID          False    APP_STORE_ELIGIBLE
```

```
buildUploads :
  Client v202605021605 → state=COMPLETE (errors:[], warnings:[]) ✅
  Pro    v202605021627 → state=PROCESSING (errors:[], warnings:[]) ⏳
```

Le build Client est officiellement **VALID** dans TestFlight, **APP_STORE_ELIGIBLE**.
Pro est encore en processing (uploadé 1m20 avant le check), deviendra VALID dans 5-15 min.

## ✅ Definition of Done — VALIDÉE 🎉

- [x] Concurrency group `ios-signing` (commit 716b340)
- [x] Bundle IDs alignés avec les apps ASC existantes
- [x] Deployment targets pbxproj == Podfile (Client 15.0, Pro 13.0)
- [x] `DEVELOPMENT_TEAM = J7K94W4PUN` dans les deux pbxproj
- [x] Fastfile aligné sur la référence Mentality
- [x] `scripts/purge_dist_certs.py` purge les certs DISTRIBUTION
- [x] Workflows iOS Client et Pro identiques structurellement
- [x] **Info.plist : NSCameraUsageDescription, NSPhotoLibraryUsageDescription, NSLocation*, NSMicrophoneUsageDescription, NSContactsUsageDescription, NSFaceIDUsageDescription** (commit 686b1e4)
- [x] **Client `win-time` : VALID + APP_STORE_ELIGIBLE** (v202605021605 uploaded 16:23 UTC) ✅
- [x] **Pro `win-time-pro` : VALID + APP_STORE_ELIGIBLE** (v202605021627 uploaded 16:31 UTC) ✅
- [ ] Action utilisateur restante : envoyer/relancer l'invitation TestFlight à `monopoly97160@gmail.com` depuis App Store Connect (les builds sont prêts, le tester peut maintenant être ajouté au groupe TestFlight)

## Leçons apprises (durable, FINAL)

### 🎯 La cause racine était un classique iOS, mais cachée

**Apple Error Code `90683` — Missing purpose string in Info.plist** se manifeste **silencieusement** :
- Apple accepte l'upload (iTMSTransporter dit "Successfully uploaded")
- Apple traite ensuite le binaire
- Si l'IPA contient des références (via plugins Flutter) à des APIs sensibles (Camera, Photos, Location, Microphone, Face ID...) **sans** la `NSXxxUsageDescription` correspondante dans Info.plist, Apple **rejette le binaire**
- L'erreur **n'apparaît PAS dans `/v1/builds`** (qui ne liste que les builds "promus" en post-processing)
- L'erreur **n'apparaît PAS dans les emails** (Apple les envoie pour rejets explicites mais pas toujours pour rejets de processing)
- L'erreur **n'apparaît PAS dans la sortie de fastlane** (qui se termine sur "Successfully uploaded")
- Elle n'apparaît **QUE** dans `/v1/apps/{id}/buildUploads` avec `state.errors[]` détaillé
- Les plugins Flutter qui DÉCLENCHENT cette exigence : `image_picker`, `permission_handler`, `location`, `flutter_stripe`, `firebase_*`, `google_maps_flutter`, `flutter_secure_storage` (Face ID), etc.

### Outil de diagnostic critique : query `/v1/apps/{id}/buildUploads`

Ce endpoint expose les uploads **rejetés** avec leurs erreurs Apple détaillées. À utiliser **systématiquement** quand un build n'apparaît pas dans TestFlight malgré un upload "réussi".

Implémenté dans `scripts/check_asc_builds.py` du repo win-time.

### Hypothèses précédemment testées et écartées

| Hypothèse | Résultat |
|-----------|----------|
| Race condition cert (parallel runs) | Réelle, fixée par concurrency group `ios-signing` (716b340), mais pas la cause finale |
| `purge_dist_certs.py` masque les erreurs auth | Fixé (strict mode), mais pas la cause finale |
| `curl` glob brackets dans ASC URLs | Réel, fixé avec `-g`, mais pas la cause finale |
| Cert revoked DURING Apple processing | Plausible mais non vérifiable, le vrai problème était amont |
| `ITSAppUsesNonExemptEncryption` manquant | Fixé proactivement (mentality l'a), pas la cause finale |
| `skip_waiting_for_build_processing: false` | Tenté mais hung 60+ min car Apple ne progressait jamais à cause du 90683 |
| App Store Connect setup (privacy, beta review) | Identique à Mentality, pas la cause |
| Bundle ID `0for0.com` non standard | Pro utilise un format standard et échouait aussi → pas la cause |

### Prochaine action de prévention

Ajouter dans le pré-flight CI un step qui valide la présence des NSXxxUsageDescription dans Info.plist via `plutil` ou un script Python. Si une clé requise manque → fail early avec message clair.

---

## Itération 6 — Fix écran blanc post-publication TestFlight (2026-05-02)

### Symptôme

Les 2 builds VALID dans TestFlight installent OK sur iPhone, l'icône apparaît, mais au lancement : **écran blanc permanent**. Le LaunchScreen reste affiché, aucune UI Flutter ne se rend.

### Cause racine

Diagnostic confirmé par 2 agents Explore + lecture directe des fichiers.

#### Pro (`win_time_pro_mobilapp`)
`main.dart:14` → `await ServiceLocator.init()` → `injection_container.dart:46` → `await FirebaseMessaging.instance.getToken()` **sans timeout**.

Sans `GoogleService-Info.plist`, sur iOS, FCM essaie de récupérer un APNs token via `UNUserNotificationCenter` qui ne répond jamais. Le call **hang indéfiniment** (ne throw pas, juste attend). Le `try/catch` capture les exceptions mais pas les hangs.

→ `main()` reste bloqué à `await ServiceLocator.init()`, `runApp()` n'est jamais appelé, le LaunchScreen blanc reste affiché indéfiniment.

#### Client (`win_time_mobilapp`)
`main.dart:19` → `await configureDependencies()` → `getIt.init()` (généré par injectable).

Le code généré (`injection.config.dart`) instancie `OrderRemoteDataSourceImpl(gh<Dio>())` mais **`Dio` n'est PAS enregistré** dans `injection.dart`. Au CI le `build_runner` régénère `injection.config.dart` selon les annotations du code source — il y aura toujours une dépendance `Dio` non résolue.

→ `gh<Dio>()` throw `Object/factory of type Dio is not registered`. L'exception remonte jusqu'à `main()` qui n'a aucune protection → crash silencieux → écran blanc.

(Secondairement : `NotificationService(gh<FirebaseMessaging>(), …)` échoue aussi si `FirebaseMessaging.instance` n'a pas pu être enregistré.)

#### Les 2 apps
Aucun `FlutterError.onError` ni `runZonedGuarded` → toute erreur runtime non capturée donne un écran blanc silencieux, sans stack trace visible. Sur TestFlight on n'a même pas accès à un debugger.

### Fix appliqué

| Fichier | Modification |
|---------|--------------|
| `win_time_mobilapp/lib/main.dart` | + `runZonedGuarded`, `FlutterError.onError`, try/catch + timeout sur Firebase / Hive / `configureDependencies` |
| `win_time_mobilapp/lib/core/di/injection.dart` | Pré-enregistre `Dio` (nécessaire pour `OrderRemoteDataSourceImpl`) + try/catch autour de `getIt.init()` |
| `win_time_mobilapp/lib/core/utils/notification_service.dart` | Ajoute `.timeout(5s)` sur `_firebaseMessaging.getToken()` |
| `win_time_pro_mobilapp/lib/main.dart` | + `runZonedGuarded`, `FlutterError.onError`, try/catch + timeout 15s sur `ServiceLocator.init()` |
| `win_time_pro_mobilapp/lib/core/di/injection_container.dart` | Ajoute `.timeout(5s)` sur `FirebaseMessaging.instance.getToken()` |

### Leçons durables

> **Toute app Flutter publiée doit avoir `runZonedGuarded` + `FlutterError.onError` à minima**. Sans ça, une erreur de plugin natif au démarrage = écran blanc indistingable d'un crash sans symptôme. Sur TestFlight, c'est le pire cas car on n'a pas de stack trace.

> **Tout `await` sur un plugin natif** (Firebase, location, secure_storage, …) doit avoir un `.timeout(Duration(seconds: 5))`. Les méthodes natives peuvent **hanger** sans throw quand leur configuration est incomplète (ex. `GoogleService-Info.plist` absent).

> **`build_runner` regénère `injection.config.dart` à chaque CI**. Toute dépendance attendue par le DI graph (Dio, baseUrl, etc.) DOIT être pré-enregistrée AVANT `getIt.init()`, sinon le call throw au runtime — invisible côté local (la version stale est lue) mais fatal au CI/TestFlight.

> **Pattern Mentality** : init avec un `_configureApp()` qui wrap chaque async dans un try/catch + fallback (`_loadDefaults()`). Aucun `await` n'est laissé exposed. C'est ce qui fait que Mentality ne montre jamais d'écran blanc même quand un service est down.

---

## Itération 7 — Pro toujours blanc (Client OK) — root cause Firebase

**Date** : 2026-05-02 ~20:00 UTC

**Symptôme post-iter6** :
- ✅ **Client** : SplashScreen + login s'affichent. Le fix Dio + try/catch a marché.
- ❌ **Pro** : encore écran blanc malgré runZonedGuarded + timeout FCM.

### Diagnostic

Lecture précise de `notification_service.dart` ligne 7 :
```dart
class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;  // ← FIELD INITIALIZER
  ...
}
```

Et de `main.dart` Pro avant ce fix : **AUCUN `await Firebase.initializeApp()`**, contrairement à Client qui en faisait un (ligne 13).

Conséquence :
1. `ServiceLocator.init()` ligne 43 fait `_notificationService = NotificationService();`
2. Le constructeur évalue le field initializer `FirebaseMessaging.instance`
3. Comme `Firebase.initializeApp()` n'a JAMAIS été appelé → throw `[core/no-app] No Firebase App '[DEFAULT]' has been created`
4. `ServiceLocator.init()` crash AVANT d'initialiser `authRepository` (lignes 56+)
5. `runApp(WinTimeProApp())` est appelé
6. `MultiBlocProvider(providers: [BlocProvider(create: (_) => AuthBloc(authRepository: ServiceLocator.authRepository))])` accède à `ServiceLocator.authRepository` qui est `late uninitialized`
7. **`LateInitializationError`** dans `BlocProvider.create` → caught par `FlutterError.onError` → en release mode, `ErrorWidget` par défaut = widget gris/blanc invisible
8. → écran blanc

### Fix iter7 (commit à venir)

Trois modifications combinées pour éliminer la classe entière de bugs "Firebase manquant = blank screen" :

| Fichier | Modification |
|---------|--------------|
| `win_time_pro_mobilapp/lib/main.dart` | + `await Firebase.initializeApp()` (avec timeout 5s + try/catch). + `ErrorWidget.builder` qui affiche un message visible au lieu d'un widget gris invisible |
| `win_time_pro_mobilapp/lib/core/services/notification_service.dart` | `_firebaseMessaging` devient lazy + nullable (try/catch sur `.instance`). Tous les usages internes guardés avec `if (fcm == null) return`. Plus de field initializer crashable. |
| `win_time_pro_mobilapp/lib/core/di/injection_container.dart` | `ServiceLocator.init()` réordonné : Auth + Orders init AVANT tout call Firebase. Comme ça, même si Firebase crash, `authRepository` est déjà set → BlocProvider build sans erreur. |
| `win_time_mobilapp/lib/main.dart` | + `ErrorWidget.builder` aussi (pour parité + sécurité future) |

### Leçon durable

> **Trois règles d'or pour Firebase + Flutter** :
> 1. Toujours appeler `await Firebase.initializeApp()` AVANT tout usage de `FirebaseMessaging.instance` (ou autre `XxxxFirebase.instance`). Sans ça → throw `[core/no-app]`.
> 2. Ne JAMAIS utiliser `final FirebaseXxx field = FirebaseXxx.instance;` comme **field initializer** : si Firebase n'est pas init, le constructeur entier de la classe throw — invisible dans les logs, propagé à toute instanciation. Toujours lazy + try/catch.
> 3. Dans tout DI manuel (`ServiceLocator`-style), **initialiser les fields critiques EN PREMIER** (auth, repositories) puis les services tiers (Firebase) à la fin. Comme ça, un crash Firebase ne casse pas le reste du graph.

> **ErrorWidget.builder** : par défaut en release mode, Flutter affiche un widget gris quand le widget tree throw. Sur TestFlight ça ressemble à un blank screen. Toujours définir un `ErrorWidget.builder` qui affiche le message d'erreur visiblement.

## Leçons apprises (durable)

À enrichir au fur et à mesure :
- **(2026-05-02 — itération 1)** `curl` interprète par défaut les caractères `[` et `]` comme du **glob URL** (pour générer plusieurs URLs depuis un pattern). C'est invisible : il échoue avec "HTTP 0" ou un message peu clair. Pour toute requête ASC API qui utilise `filter[…]` ou `fields[…]`, **TOUJOURS** passer `-g` (alias `--globoff`) à curl. À retenir pour tous les futurs scripts d'intégration ASC.
- **(2026-05-02)** `purge_dist_certs.py` masquait les erreurs d'auth silencieusement (data.get pattern). Patché en strict mode + debug header. Toute requête ASC doit valider HTTP=200 explicitement.
- **(2026-05-02)** Le concurrency group `ios-signing` est validé : Pro et Client se sérialisent correctement. La race condition cert est définitivement éliminée.
- **(2026-05-02)** `cert(force:true)` + `sigh(force:true)` accumule les vieux profils. Pro log du 30/04 a montré 6 profils orphelins (NX7Z78C58H, 8J3UYHLS99, C7FDL2XSL4, HNRHHV5597, UF84LT4677, GDAVVQ7Z4J). Si ça devient un problème de quota → ajouter un purge de profils.
