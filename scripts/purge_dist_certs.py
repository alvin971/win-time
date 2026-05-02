"""
Supprime tous les certificats DISTRIBUTION orphelins dans App Store Connect.
Évite l'erreur "maximum number of certificates generated" en CI.

Strict sur les erreurs : si l'API ASC répond autre chose que 2xx (par ex. 401
si la clé .p8 est invalide), le script imprime le code HTTP et la réponse
brute puis sys.exit(1). Sans ça, un échec d'auth se masquait silencieusement
en "0 cert(s) trouvés" et empêchait de diagnostiquer la cause réelle.

Usage:
    APP_STORE_KEY_ID=... APP_STORE_ISSUER_ID=... APP_STORE_API_KEY_CONTENT=... \\
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
    """GET ASC — returns (http_code, parsed_json_or_raw)."""
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


def asc_delete(cert_id):
    r = subprocess.run(
        ["curl", "-s", "--max-time", "30", "-X", "DELETE",
         "-o", "/dev/null", "-w", "%{http_code}"] + HEADERS + [f"{BASE}/v1/certificates/{cert_id}"],
        capture_output=True, text=True
    )
    return r.stdout.strip()


print(f"DEBUG: KEY_ID={KEY_ID[:4]}***  ISSUER_ID={ISSUER_ID[:8]}***  PEM_len={len(PEM)}  PEM_starts={PEM[:30]!r}")

code, data = asc_get("/v1/certificates?limit=200")
if code != 200:
    print(f"❌ ASC API auth FAILED — HTTP {code}", file=sys.stderr)
    print(f"   Response: {json.dumps(data, indent=2)[:800]}", file=sys.stderr)
    sys.exit(1)

certs = data.get("data", [])
dist  = [c for c in certs if "DISTRIBUTION" in c["attributes"]["certificateType"]]
print(f"Certs DISTRIBUTION trouvés : {len(dist)} (sur {len(certs)} certs au total)")

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
