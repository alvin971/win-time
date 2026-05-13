# Win Time — Onboarding (clone to first commit in under 2 h)

Welcome. This document is the **single starting point** for a new developer on win-time. If you find anything in here stale, fix it and commit — that's part of onboarding.

## 0. What is win-time?

A French-market **Click & Collect platform for restaurants**, two Flutter apps + a shared Dart package on a self-hosted Supabase.

| App | Purpose |
|---|---|
| `win_time_mobilapp/` | Customer app: browse restaurants, order, pay (Stripe TBD), track pickup |
| `win_time_pro_mobilapp/` | Restaurateur app: dashboard, menu CRUD, order management |
| `packages/shared_core/` | Entities, enums, errors, geohash, validators — shared by both apps |
| `migrations/` | Postgres SQL applied to the Supabase schema `wintime` |
| `scripts/` | Node + Python helpers (seed, ASC build checks) |

## 1. Prerequisites

```bash
flutter --version   # need 3.32.x (matches CI; see .github/workflows/ci.yml)
dart --version      # bundled with Flutter
node --version      # 18+ for scripts/
python3 --version   # 3.10+ for scripts/check_asc_builds.py
```

If `flutter doctor` is unhappy, fix it before going further — Flutter web + iOS + Android targets must all be green to run CI locally.

## 2. Clone

```bash
git clone git@github.com:alvin971/win-time.git
cd win-time
```

**Do NOT use HTTPS+PAT cloning**. If `.git/config` ever shows a `ghp_…` token in the URL, treat it as a leak and revoke immediately (the previous occurrence is documented in audit S12.1.0).

## 3. Install Dart deps (the order matters)

```bash
# shared_core MUST go first — both apps path-depend on it
( cd packages/shared_core && flutter pub get )

( cd win_time_mobilapp && flutter pub get )
( cd win_time_pro_mobilapp && flutter pub get )
```

## 4. Code generation

```bash
( cd win_time_mobilapp && dart run build_runner build --delete-conflicting-outputs )
( cd win_time_pro_mobilapp && dart run build_runner build --delete-conflicting-outputs )
```

## 5. Backend

The Supabase instance at `https://supabase.0for0.com` is already running with the `wintime` schema seeded. The Flutter apps' `wintime_supabase_config.dart` already points at it with the anon key.

**To re-apply migrations** (e.g., after pulling a new one from `migrations/`):

```bash
# SSH access to the VPS is required. See SETUP_SUPABASE.md for the docker exec recipe.
docker cp migrations/20260504_010_wintime_schema.sql supabase-db:/tmp/010.sql
docker exec supabase-db psql -U postgres -d postgres -f /tmp/010.sql
```

**To re-seed the demo accounts** (eight users, four restaurants):

```bash
cd scripts
cp .env.example .env   # then fill in SUPABASE_SERVICE_ROLE from Studio
./seed_demo.sh
```

Demo accounts and passwords are documented in `SETUP_SUPABASE.md`.

## 6. Run

```bash
# Web (fastest to iterate)
( cd win_time_mobilapp && flutter run -d chrome )
( cd win_time_pro_mobilapp && flutter run -d chrome )

# iOS Simulator (needs Xcode 26+ on macOS)
( cd win_time_mobilapp/ios && pod install --repo-update )
( cd win_time_mobilapp && flutter run -d iphone )

# Android emulator
( cd win_time_mobilapp && flutter run -d emulator-5554 )
```

If you see a white screen on first boot, check the comments in `lib/main.dart` — the `runZonedGuarded` wrapper and `ErrorWidget.builder` override will surface what went wrong instead of hanging.

## 7. Architecture in 60 seconds

- **Clean Architecture × BLoC**: features have `data/` (datasources + models + repositories), `domain/` (entities + repository interfaces + usecases), and `presentation/` (BLoC + widgets + pages).
- **DI**: Client uses `injectable` + `get_it` (generated `injection.config.dart`). Pro uses a manual `ServiceLocator` for visibility — both patterns are intentional.
- **Realtime**: orders flow via Supabase realtime channels (NOT Socket.IO, which is dead-but-in-pubspec). The schema-aware channel pattern at `supabase_orders_datasource.dart:53-77` is **mandatory** — the SDK's `.schema().from().stream()` does not respect the schema. Re-read the comment before touching that file.
- **shared_core entities are the canonical truth.** Two of the legacy entities (`win_time_mobilapp/lib/features/orders/domain/entities/order_entity.dart`) are simplified duplicates kept for legacy widget compatibility — they will be removed.

For depth: read `WINTIME.md` (project reference; some sections are stale per audit S1.5.7 — fix as you encounter drift) and `WINTIME_AUDIT_REPORT.md` (full audit, ground-truth as of 2026-05-13).

## 8. Tests

```bash
( cd win_time_mobilapp && flutter test )
( cd win_time_pro_mobilapp && flutter test )
( cd packages/shared_core && flutter test )
```

Today: only orders has real tests (`create_order_usecase_test.dart`, `orders_bloc_test.dart`). Every new BLoC / repository you add should ship with a test.

## 9. Commit hygiene

- Conventional Commits: `feat(scope):`, `fix(scope):`, `chore(scope):`, etc.
- Run `flutter analyze` in each app before opening a PR.
- Never commit `.env`, `google-services.json`, `GoogleService-Info.plist`, or anything matching `ghp_*` / `sk_live_*` / `sk_test_*`.
- The CI runs on push to `main` / `develop` and on PRs; six workflows fan out across both apps and iOS/Android/web.

## 10. When you get stuck

In order:
1. `WINTIME_AUDIT_REPORT.md` — likely already says what's wrong.
2. `wintime.md` (the lowercase one — TestFlight troubleshooting log).
3. `WINTIME.md` — beware staleness; check date.
4. Ask Alvin.

## 11. What you should NOT touch without aligning

- `migrations/*.sql` — Postgres schema. Add a new file with `_NNN_description.sql`, don't edit existing.
- `wintime_supabase_config.dart` — backend URLs and anon key. Change only if the backend moves.
- `core/router/app_router.dart` (client) and `dashboard_page.dart` (Pro) — load-bearing for cold start; coordinate.
- `.github/workflows/*.yml` — CI signing, store deploys; reach the team before changing.
