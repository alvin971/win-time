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

## Leçons apprises (durable)

À enrichir au fur et à mesure :
- **(2026-05-02)** `purge_dist_certs.py` masque les erreurs d'authentification ASC silencieusement : si l'API renvoie 401/403, le script affiche "0 certs trouvés" comme si tout allait bien. Cela rend très difficile de diagnostiquer un problème d'auth quand il survient. → toujours valider le statut HTTP avant de parser le JSON.
- **(2026-05-02)** Le concurrency group `ios-signing` a marché : Pro et Client se sont sérialisés correctement (Client a queued 30s après Pro). Donc la race condition cert est éliminée — c'est un autre problème.
- **(2026-05-02)** `cert(force:true)` + `sigh(force:true)` accumule les vieux profils. Le log Pro montre 6 profils orphelins (NX7Z78C58H, 8J3UYHLS99, C7FDL2XSL4, HNRHHV5597, UF84LT4677, GDAVVQ7Z4J). À long terme, prévoir un script de purge de profils aussi (l'équivalent de `purge_dist_certs.py` pour `/v1/profiles`).
