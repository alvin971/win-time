"""
Supprime tous les certificats DISTRIBUTION orphelins dans App Store Connect.
Évite l'erreur "maximum number of certificates generated" en CI.

Usage:
    APP_STORE_KEY_ID=... APP_STORE_ISSUER_ID=... APP_STORE_API_KEY_CONTENT=... \
    python3 scripts/purge_dist_certs.py
"""
import jwt, time, json, subprocess, os, sys

KEY_ID    = os.environ["APP_STORE_KEY_ID"]
ISSUER_ID = os.environ["APP_STORE_ISSUER_ID"]
PEM       = os.environ["APP_STORE_API_KEY_CONTENT"]

token = jwt.encode(
    {"iss": ISSUER_ID, "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"},
    PEM, algorithm="ES256", headers={"kid": KEY_ID}
)

BASE    = "https://api.appstoreconnect.apple.com"
HEADERS = ["-H", f"Authorization: Bearer {token}", "-H", "Content-Type: application/json"]

def asc_get(path):
    r = subprocess.run(
        ["curl", "-s", "--max-time", "30"] + HEADERS + [f"{BASE}{path}"],
        capture_output=True, text=True
    )
    return json.loads(r.stdout)

def asc_delete(cert_id):
    r = subprocess.run(
        ["curl", "-s", "--max-time", "30", "-X", "DELETE",
         "-o", "/dev/null", "-w", "%{http_code}"] + HEADERS + [f"{BASE}/v1/certificates/{cert_id}"],
        capture_output=True, text=True
    )
    return r.stdout.strip()

data  = asc_get("/v1/certificates?limit=20")
certs = data.get("data", [])
dist  = [c for c in certs if "DISTRIBUTION" in c["attributes"]["certificateType"]]
print(f"Certs DISTRIBUTION trouvés : {len(dist)}")

failures = 0
for c in dist:
    http_status = asc_delete(c["id"])
    if http_status == "204":
        print(f"  OK  supprimé {c['id']} ({c['attributes']['name']})")
    else:
        print(f"  ERR {c['id']} ({c['attributes']['name']}) → HTTP {http_status}", file=sys.stderr)
        failures += 1

if failures:
    print(f"WARN : {failures} cert(s) non supprimé(s).")
else:
    print(f"Quota libéré ({len(dist)} cert(s) supprimé(s)).")
