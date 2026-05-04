#!/usr/bin/env bash
# Win Time — Wrapper de seed Supabase pour la démo end-to-end.
#
# Usage : ./scripts/seed_demo.sh
#
# Prérequis :
#   - Node ≥ 18
#   - Fichier scripts/.env (cf. .env.example) avec SUPABASE_URL et SUPABASE_SERVICE_ROLE
#   - Migrations SQL appliquées sur le Postgres (voir SETUP_SUPABASE.md)
#
# Idempotent — peut être relancé sans dupliquer les données.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
  echo "❌ ${SCRIPT_DIR}/.env introuvable."
  echo "   Copie : cp ${SCRIPT_DIR}/.env.example ${SCRIPT_DIR}/.env"
  echo "   Puis remplis SUPABASE_URL et SUPABASE_SERVICE_ROLE."
  exit 1
fi

if [[ ! -d "${SCRIPT_DIR}/node_modules" ]]; then
  echo "▶ Installation des dépendances Node (première fois)..."
  (cd "$SCRIPT_DIR" && npm install --silent)
fi

echo "▶ Seed Win Time → schéma wintime"
node "${SCRIPT_DIR}/seed_supabase.js"

echo ""
echo "✅ Seed OK. Comptes (password = demo-pass-1234) :"
echo "   • owner.demo@wintime.test     → Pro (restaurantOwner, La Trattoria)"
echo "   • manager.demo@wintime.test   → Pro (restaurantManager)"
echo "   • staff.demo@wintime.test     → Pro (restaurantStaff)"
echo "   • admin.demo@wintime.test     → Pro (admin)"
echo "   • demo.customer@wintime.test  → Client (peut commander)"
echo "   • louvre@wintime.test         → owner Bistrot du Louvre"
echo "   • sakura@wintime.test         → owner Sakura Sushi"
echo "   • etoile@wintime.test         → owner Beirut Étoile"
