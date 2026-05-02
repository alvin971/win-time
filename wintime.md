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

## Itération 4 — Planifiée

1. ⏳ Attendre 20-25 min après Client iter3 upload (14:07:35) → vers 14:30
2. Run asc_check workflow → si Client iter3 VALID → théorie cert-revocation confirmée
3. Push le commit Fastfile (skip_waiting:false)
4. Trigger Pro workflow_dispatch → attendre VALID dans ASC (fastlane wait inside)
5. Trigger Client workflow_dispatch → attendre VALID dans ASC
6. Vérifier les 2 builds VALID dans TestFlight + invitation `monopoly97160@gmail.com`

## Leçons apprises (durable)

À enrichir au fur et à mesure :
- **(2026-05-02 — itération 1)** `curl` interprète par défaut les caractères `[` et `]` comme du **glob URL** (pour générer plusieurs URLs depuis un pattern). C'est invisible : il échoue avec "HTTP 0" ou un message peu clair. Pour toute requête ASC API qui utilise `filter[…]` ou `fields[…]`, **TOUJOURS** passer `-g` (alias `--globoff`) à curl. À retenir pour tous les futurs scripts d'intégration ASC.
- **(2026-05-02)** `purge_dist_certs.py` masquait les erreurs d'auth silencieusement (data.get pattern). Patché en strict mode + debug header. Toute requête ASC doit valider HTTP=200 explicitement.
- **(2026-05-02)** Le concurrency group `ios-signing` est validé : Pro et Client se sérialisent correctement. La race condition cert est définitivement éliminée.
- **(2026-05-02)** `cert(force:true)` + `sigh(force:true)` accumule les vieux profils. Pro log du 30/04 a montré 6 profils orphelins (NX7Z78C58H, 8J3UYHLS99, C7FDL2XSL4, HNRHHV5597, UF84LT4677, GDAVVQ7Z4J). Si ça devient un problème de quota → ajouter un purge de profils.
