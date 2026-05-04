#!/usr/bin/env bash
# Win Time — Wrapper de seed pour la démo end-to-end.
#
# Usage:
#   1. Télécharger un service account depuis :
#      Firebase Console → Project Settings → Service Accounts → Generate new private key
#      Le sauvegarder dans scripts/service-account.json (gitignored).
#
#   2. Depuis la racine du monorepo :
#      ./scripts/seed_demo.sh
#
# Prérequis :
#   - Node ≥ 18
#   - firebase-admin installé : `cd scripts && npm install`
#   - .firebaserc pointant sur le bon projet (wintime-demo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SA_PATH="${SCRIPT_DIR}/service-account.json"

if [[ ! -f "$SA_PATH" ]]; then
  echo "❌ Service account introuvable : $SA_PATH"
  echo "   Télécharger depuis : Firebase Console → Project Settings → Service Accounts"
  exit 1
fi

if [[ ! -d "${SCRIPT_DIR}/node_modules" ]]; then
  echo "▶ Installation firebase-admin (première fois)..."
  (cd "$SCRIPT_DIR" && npm install --silent)
fi

echo "▶ Seed Win Time → projet par défaut"
GOOGLE_APPLICATION_CREDENTIALS="$SA_PATH" node "${SCRIPT_DIR}/seed_firestore.js"

echo ""
echo "✅ Seed OK. Comptes de démo (password = demo-pass-1234) :"
echo "   • owner.demo@wintime.test     → Pro (restaurantOwner, owns La Trattoria)"
echo "   • manager.demo@wintime.test   → Pro (restaurantManager)"
echo "   • staff.demo@wintime.test     → Pro (restaurantStaff)"
echo "   • admin.demo@wintime.test     → Pro (admin)"
echo "   • demo.customer@wintime.test  → Client (peut commander)"
echo ""
echo "Restaurants créés :"
echo "   • La Trattoria du Châtelet (italien, 75004)"
echo "   • Le Bistrot du Louvre (français, 75001)"
echo "   • Sakura Sushi (japonais, 75004)"
echo "   • Beirut Étoile (libanais, 75017)"
