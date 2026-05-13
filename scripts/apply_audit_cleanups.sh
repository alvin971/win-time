#!/usr/bin/env bash
# scripts/apply_audit_cleanups.sh
# ----------------------------------------------------------------------------
# Applies the "destructive but reversible" cleanups from the audit Sprint 0
# (T21, T22, T23). DOES NOT push, DOES NOT force; you review the staged
# changes with `git diff --cached` and `git status`, then commit yourself.
#
# Usage:
#   bash scripts/apply_audit_cleanups.sh         # dry-run (default)
#   APPLY=1 bash scripts/apply_audit_cleanups.sh # actually do it
# ----------------------------------------------------------------------------
set -euo pipefail

APPLY="${APPLY:-0}"
run() {
  if [[ "$APPLY" = "1" ]]; then
    echo "  + $*"
    eval "$@"
  else
    echo "  (dry) $*"
  fi
}

echo "== T23 — Rename lowercase wintime.md to avoid macOS case clash =="
if [[ -f wintime.md && -f WINTIME.md ]]; then
  run "mkdir -p docs"
  run "git mv wintime.md docs/TESTFLIGHT_LOG.md"
else
  echo "  (skipped: wintime.md not found at repo root)"
fi

echo ""
echo "== T22 — Untrack legacy/ (keeps files on disk, removes from git tracking) =="
if [[ -d legacy && $(git ls-files legacy/ | head -1) ]]; then
  run "git rm -r --cached legacy/"
  # After this commit, the existing .gitignore line `legacy/` will keep the
  # directory ignored.
else
  echo "  (skipped: legacy/ not git-tracked)"
fi

echo ""
echo "== T21 — Delete dead Client code paths (lib/pages, lib/data, lib/models, main_simple, *_temp, *.bak) =="
DEAD_FILES=(
  "win_time_mobilapp/lib/main_simple.dart"
  "win_time_mobilapp/lib/data/mock_data.dart"
  "win_time_mobilapp/lib/models/restaurant_models.dart"
  "win_time_mobilapp/lib/pages/cart_page.dart"
  "win_time_mobilapp/lib/pages/checkout_page.dart"
  "win_time_mobilapp/lib/pages/login_page.dart"
  "win_time_mobilapp/lib/pages/onboarding_page.dart"
  "win_time_mobilapp/lib/pages/order_confirmation_page.dart"
  "win_time_mobilapp/lib/pages/order_tracking_page.dart"
  "win_time_mobilapp/lib/pages/register_page.dart"
  "win_time_mobilapp/lib/pages/restaurant_detail_page.dart"
  "win_time_mobilapp/lib/features/orders/data/datasources/order_remote_datasource_temp.dart"
  "win_time_mobilapp/lib/features/orders/data/datasources/order_remote_datasource.g.dart.bak"
)
for f in "${DEAD_FILES[@]}"; do
  if [[ -e "$f" ]]; then
    run "git rm -f \"$f\""
  else
    echo "  (skipped: $f not present)"
  fi
done

# Drop the now-empty directories (git itself ignores empty dirs).
run "rmdir win_time_mobilapp/lib/pages 2>/dev/null || true"
run "rmdir win_time_mobilapp/lib/data 2>/dev/null || true"
run "rmdir win_time_mobilapp/lib/models 2>/dev/null || true"

echo ""
echo "== Summary =="
if [[ "$APPLY" = "1" ]]; then
  echo "Staged changes (run 'git diff --cached' to inspect):"
  git status --short
  echo ""
  echo "If everything looks right:"
  echo "    git commit -m 'chore(audit): apply Sprint 0 cleanups T21/T22/T23'"
else
  echo "DRY-RUN. Nothing changed. Re-run with APPLY=1 to actually apply."
fi
