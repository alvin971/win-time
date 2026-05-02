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
    """Returns (http_code, parsed_json). Raises on transport failure."""
    r = subprocess.run(
        ["curl", "-s", "--max-time", "30", "-w", "\n__HTTP_CODE__%{http_code}"]
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
