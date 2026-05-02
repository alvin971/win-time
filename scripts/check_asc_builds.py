"""
Thermomètre TestFlight : interroge l'API App Store Connect et imprime
l'état des builds pour win-time (6764433401) et win-time-pro (6764434885).

Usage:
    APP_STORE_KEY_ID=... APP_STORE_ISSUER_ID=... APP_STORE_API_KEY_CONTENT=... \\
    python3 scripts/check_asc_builds.py
"""
import jwt, time, json, subprocess, os, sys, datetime

KEY_ID    = os.environ["APP_STORE_KEY_ID"]
ISSUER_ID = os.environ["APP_STORE_ISSUER_ID"]
PEM       = os.environ["APP_STORE_API_KEY_CONTENT"]

token = jwt.encode(
    {"iss": ISSUER_ID, "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"},
    PEM, algorithm="ES256", headers={"kid": KEY_ID}
)

BASE    = "https://api.appstoreconnect.apple.com"
HEADERS = ["-H", f"Authorization: Bearer {token}", "-H", "Content-Type: application/json"]

APPS = {
    "win-time (Client)": "6764433401",
    "win-time-pro":      "6764434885",
}


def asc_get(path):
    """Returns (http_code, parsed_json). Raises on transport failure.

    -g = --globoff : disable URL globbing so `filter[app]=...` brackets
    aren't interpreted as a glob pattern (otherwise curl returns HTTP 0
    silently). ASC uses `filter[…]` and `fields[…]` syntax pervasively.
    """
    r = subprocess.run(
        ["curl", "-s", "-g", "--max-time", "30", "-w", "\n__HTTP_CODE__%{http_code}"]
        + HEADERS + [f"{BASE}{path}"],
        capture_output=True, text=True
    )
    body, _, code = r.stdout.rpartition("__HTTP_CODE__")
    body = body.rstrip("\n")
    try:
        parsed = json.loads(body) if body else {}
    except json.JSONDecodeError:
        parsed = {"raw": body}
    return int(code) if code else 0, parsed


def fmt_date(iso):
    if not iso:
        return "—"
    try:
        dt = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M UTC")
    except Exception:
        return iso


print(f"=== Thermomètre ASC TestFlight — {datetime.datetime.utcnow():%Y-%m-%d %H:%M:%S UTC} ===\n")

# Auth sanity-check
code, payload = asc_get("/v1/apps?limit=1")
if code != 200:
    print(f"❌ ASC API auth FAILED — HTTP {code}")
    print(f"   Response: {json.dumps(payload, indent=2)[:500]}")
    sys.exit(2)
print(f"✅ ASC API auth OK (HTTP {code})\n")

global_failed = False

for app_name, app_id in APPS.items():
    print(f"--- {app_name} (App ID {app_id}) ---")

    # Builds (most recent first)
    code, payload = asc_get(
        f"/v1/builds?filter[app]={app_id}"
        "&sort=-uploadedDate"
        "&limit=10"
        "&fields[builds]=version,uploadedDate,expired,processingState,buildAudienceType"
    )
    if code != 200:
        print(f"  ❌ Builds query failed — HTTP {code}")
        print(f"     Response: {json.dumps(payload, indent=2)[:400]}")
        global_failed = True
        continue

    builds = payload.get("data", [])
    if not builds:
        print(f"  ⚠️  Aucun build présent dans ASC pour cette app.")
    else:
        print(f"  {len(builds)} build(s) trouvé(s) — affichage des 5 plus récents :")
        print(f"  {'Version':<14} {'Uploaded':<22} {'State':<14} {'Expired':<8} {'Audience'}")
        for b in builds[:5]:
            a = b.get("attributes", {})
            print(
                f"  {a.get('version','?'):<14} "
                f"{fmt_date(a.get('uploadedDate')):<22} "
                f"{a.get('processingState','?'):<14} "
                f"{str(a.get('expired','?')):<8} "
                f"{a.get('buildAudienceType','?')}"
            )

    # Beta groups (sanity)
    code, payload = asc_get(f"/v1/apps/{app_id}/betaGroups?limit=10&fields[betaGroups]=name,isInternalGroup")
    if code == 200:
        groups = payload.get("data", [])
        gnames = ", ".join(
            f"{g['attributes']['name']}({'int' if g['attributes']['isInternalGroup'] else 'ext'})"
            for g in groups
        )
        print(f"  Beta groups : {gnames or '—'}")

    print()

if global_failed:
    sys.exit(1)

# --- Diagnostic supplémentaire : voir TOUS les builds du compte (sans filter app) ---
print("--- Diagnostic complet : tous les builds du compte (max 20 plus récents) ---")
code, payload = asc_get(
    "/v1/builds?sort=-uploadedDate&limit=20"
    "&fields[builds]=version,uploadedDate,expired,processingState,buildAudienceType"
    "&include=app&fields[apps]=name,bundleId"
)
if code != 200:
    print(f"  ❌ Builds (no filter) HTTP {code}")
else:
    builds = payload.get("data", [])
    apps_lookup = {a["id"]: a["attributes"] for a in payload.get("included", []) if a["type"] == "apps"}
    if not builds:
        print("  ⚠️  Aucun build dans tout le compte (toutes apps confondues).")
    else:
        print(f"  {'App':<40} {'Version':<14} {'Uploaded':<22} {'State':<14}")
        for b in builds:
            a = b.get("attributes", {})
            app_rel = b.get("relationships", {}).get("app", {}).get("data", {})
            app_id = app_rel.get("id", "?")
            app_attr = apps_lookup.get(app_id, {})
            label = f"{app_attr.get('name','?')} ({app_attr.get('bundleId','?')})"
            print(
                f"  {label[:39]:<40} "
                f"{a.get('version','?'):<14} "
                f"{fmt_date(a.get('uploadedDate')):<22} "
                f"{a.get('processingState','?'):<14}"
            )

# --- Diagnostic : preReleaseVersions par app ---
print("\n--- Pre-release versions ---")
for app_name, app_id in APPS.items():
    code, payload = asc_get(
        f"/v1/apps/{app_id}/preReleaseVersions"
        "?sort=-version&limit=5"
        "&fields[preReleaseVersions]=version,platform"
    )
    if code != 200:
        print(f"  {app_name}: ❌ HTTP {code}")
        continue
    versions = payload.get("data", [])
    if not versions:
        print(f"  {app_name}: ⚠️  aucune preReleaseVersion")
    else:
        print(f"  {app_name}: {len(versions)} version(s) — {[v['attributes']['version'] for v in versions]}")

# --- Diagnostic : Apps state ---
print("\n--- État des apps ---")
for app_name, app_id in APPS.items():
    code, payload = asc_get(f"/v1/apps/{app_id}?fields[apps]=name,bundleId,sku,primaryLocale,contentRightsDeclaration")
    if code == 200:
        a = payload.get("data", {}).get("attributes", {})
        print(f"  {app_name}: name={a.get('name')} bundleId={a.get('bundleId')} sku={a.get('sku')} contentRights={a.get('contentRightsDeclaration')}")
    else:
        print(f"  {app_name}: HTTP {code}")

# --- Diagnostic supplémentaire iter 4 : appInfos, appPrivacy, betaAppReviewDetails ---
print("\n--- App Infos (état info / requirements ASC) ---")
for app_name, app_id in APPS.items():
    code, payload = asc_get(f"/v1/apps/{app_id}/appInfos?fields[appInfos]=appStoreState,appStoreAgeRating,brazilAgeRating,kidsAgeBand,primaryCategory,primarySubcategoryOne,primarySubcategoryTwo,secondaryCategory,secondarySubcategoryOne,secondarySubcategoryTwo,state")
    if code == 200:
        infos = payload.get("data", [])
        for info in infos:
            a = info.get("attributes", {})
            print(f"  {app_name}: appStoreState={a.get('appStoreState')} state={a.get('state')}")
    else:
        print(f"  {app_name}: appInfos HTTP {code}")

print("\n--- Beta App Review Detail (1st build review status) ---")
for app_name, app_id in APPS.items():
    code, payload = asc_get(f"/v1/apps/{app_id}/betaAppReviewDetail")
    if code == 200:
        a = payload.get("data", {}).get("attributes", {}) if payload.get("data") else {}
        print(f"  {app_name}: contactEmail={a.get('contactEmail')} demoAccountRequired={a.get('demoAccountRequired')} contactFirstName={a.get('contactFirstName')}")
    else:
        print(f"  {app_name}: HTTP {code}")

print("\n--- Beta License Agreement (TF EULA accepted?) ---")
for app_name, app_id in APPS.items():
    code, payload = asc_get(f"/v1/apps/{app_id}/betaLicenseAgreement")
    if code == 200:
        a = payload.get("data", {}).get("attributes", {}) if payload.get("data") else {}
        license_text = (a.get('agreementText') or '')[:80]
        print(f"  {app_name}: licenseText={license_text!r}")
    else:
        print(f"  {app_name}: HTTP {code}")

print("\n--- Test sans filter — tous les builds liés (alternative GET) ---")
for app_name, app_id in APPS.items():
    code, payload = asc_get(f"/v1/apps/{app_id}/builds?limit=5&fields[builds]=version,uploadedDate,processingState,expired")
    if code == 200:
        builds = payload.get("data", [])
        print(f"  {app_name}: {len(builds)} build(s) via /apps/{{id}}/builds")
        for b in builds[:3]:
            a = b.get("attributes", {})
            print(f"    {a.get('version')} {fmt_date(a.get('uploadedDate'))} {a.get('processingState')} expired={a.get('expired')}")
    else:
        print(f"  {app_name}: HTTP {code} body={json.dumps(payload, indent=2)[:200]}")

# --- Toutes les apps visibles par cette clé API ---
print("\n--- Toutes les apps accessibles avec cette clé ASC ---")
code, payload = asc_get("/v1/apps?limit=50&fields[apps]=name,bundleId,sku")
if code == 200:
    apps_all = payload.get("data", [])
    print(f"  {len(apps_all)} app(s) visibles :")
    for a in apps_all:
        attr = a.get("attributes", {})
        print(f"    {a.get('id'):<14} name={attr.get('name'):<25} bundleId={attr.get('bundleId')}")
else:
    print(f"  HTTP {code}")

# --- Pre-release versions (sans sort qui faisait HTTP 400) ---
print("\n--- Pre-release versions (sans sort) ---")
for app_name, app_id in APPS.items():
    code, payload = asc_get(f"/v1/apps/{app_id}/preReleaseVersions?limit=5&fields[preReleaseVersions]=version,platform")
    if code != 200:
        print(f"  {app_name}: ❌ HTTP {code} body={json.dumps(payload, indent=2)[:200]}")
        continue
    versions = payload.get("data", [])
    if not versions:
        print(f"  {app_name}: ⚠️  aucune preReleaseVersion")
    else:
        print(f"  {app_name}: {len(versions)} version(s) — {[v['attributes']['version'] for v in versions]}")
