# CLAUDE.md — VSLA Ledger

Instructions for Claude Code (and any AI or human assistant) working in this repo.
Read this file fully before doing anything. Then read `context.md` if it exists (private,
gitignored, holds the running project state).

---

## 1. What this project is

VSLA Ledger is an **open-source, offline-first Flutter app** for Village Savings and Loan
Associations (VSLAs): groups of 15–30 people who save weekly and lend to each other.
The treasurer records savings, loans and repayments on a phone, often under a tree with no
signal. Records must never be lost and must sync when a connection appears.

It is also the live demo for the talk *"Building for Ourselves: Why Open Source and
Local-First Mobile Apps Matter for African Developers"* (Kevin Ziyada Aseru and Julian
Zaabu Kayikayi, droidcon Uganda 2026). So the code is **teaching material**: clarity beats
cleverness everywhere.

Three things the codebase must always demonstrate:

1. **Local-first:** the phone's database is the source of truth. The UI never waits on the network.
2. **No vendor lock-in:** every backend sits behind one Dart interface (`LedgerRemote`) and is
   swappable with a single provider change.
3. **Contributor-friendly:** a newcomer can clone, run (with no server), and open a passing PR on day one.

---

## 2. Stack

| Concern | Choice |
| --- | --- |
| Framework | Flutter (stable channel), Dart 3 |
| Local database | `drift` + `drift_flutter` (SQLite) |
| State + DI | `flutter_riverpod` + `riverpod_annotation` (code generation) |
| Navigation | `go_router` |
| Models | `freezed` + `json_serializable` |
| Background sync | `workmanager` |
| Connectivity hint | `connectivity_plus` |
| IDs | `uuid` (v4, generated on device) |
| Backends | `pocketbase` (self-hosted), `cloud_firestore` (vendor comparison), `supabase_flutter` (later) |
| Phone-to-phone | `nearby_connections` (behind its own `PeerSync` interface) |
| Encryption | SQLCipher via `sqlite3` 3.x + `flutter_secure_storage`, **after the talk** (`sqlcipher_flutter_libs` is end-of-life) |
| Lints | `very_good_analysis` |
| Tests | `flutter_test`, `mocktail`, Drift in-memory database |

Before adding **any** new package: check it on pub.dev (recent release, Dart 3 support,
maintained), and record why in `context.md`. Prefer fewer dependencies.

---

## 3. Architecture rules (non-negotiable)

1. **The UI reads only from Drift**, via `watch()` streams exposed through Riverpod providers.
   No screen or widget ever calls a network API directly.
   *One deliberate exception:* `lib/features/demo/`, built only with `--dart-define=DEMO=true`,
   saves the "online-only" way on purpose, to show on stage why we don't (agreed 2026-10-20).
   Nothing outside that folder may copy it.
2. **Every user write goes to the entity table AND the `outbox` table in one Drift
   transaction.** Never write one without the other.
3. **`ledger_entries` is append-only.** No `UPDATE` or `DELETE` on it, ever. Mistakes are
   fixed with a `correction` entry pointing at the original (`correctsEntryId`).
4. **Balances are calculated from entries, never stored.**
5. **Money is whole Uganda shillings in `int`.** Never `double` for money.
6. **IDs are UUID v4 generated on the device.** Nothing waits for a server-issued ID.
7. **Vendor packages (`pocketbase`, `cloud_firestore`, `firebase_*`, `supabase_flutter`,
   `nearby_connections`) may only be imported inside `lib/remote/` (or `lib/peer/` for
   nearby).** CI fails the build otherwise. Vendor types never leave an adapter.
8. **The `fake` backend must always work.** `flutter run --dart-define=BACKEND=fake` runs the
   whole app with no server and no internet. Never break this; it's how contributors start.
9. **Pushes are idempotent.** The server upserts by `id`, so retrying a push is harmless.
10. **Real money never moves in this app.** It records savings. Anything touching real
    payments needs an explicit decision recorded in `context.md` first.

If a task seems to require breaking one of these, **stop and ask**. Don't work around it.

---

## 4. Folder structure

```
lib/
  main.dart              # Reads BACKEND dart-define, sets provider overrides, runs app
  app/                   # MaterialApp, theme, go_router routes
  core/
    models/              # Freezed domain models (Group, Member, LedgerEntry, OutboxItem)
    database/            # Drift tables, DAOs, migrations
    sync/                # LedgerRemote interface, SyncService, sync triggers
    providers.dart       # Core Riverpod providers
  features/
    groups/  members/  ledger/  nearby_share/   # screens, widgets, controllers per feature
  remote/                # ONLY place backend vendor packages are imported
    pocketbase_remote.dart  firebase_remote.dart  fake_remote.dart
  peer/                  # PeerSync interface + nearby_connections adapter
  l10n/                  # ARB files (app_en.arb; app_lg.arb for Luganda later)
test/                    # mirrors lib/
integration_test/
server/pocketbase/       # pb_schema.json + how to run PocketBase locally
docs/                    # architecture.md, adr/
plans/                   # private task plans (gitignored)
context.md               # private running project state (gitignored)
```

---

## 5. Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after changing any @riverpod / @freezed / drift table
dart format .
flutter analyze
flutter test
flutter run --dart-define=BACKEND=fake                       # no server needed
flutter run --dart-define=BACKEND=pocketbase --dart-define=PB_URL=http://10.0.2.2:8090
flutter run --dart-define=DEMO=true --dart-define=DEMO_DELAY_MS=3000  # talk demo: slow network
flutter build apk --debug
```

`10.0.2.2` is the Android emulator's alias for the host machine. On a real phone use the
laptop's LAN IP.

**Definition of done for any change:** `dart format`, `flutter analyze` (zero issues) and
`flutter test` all pass, the `fake` backend still runs, and `context.md` has a dated note.

---

## 6. How we work (follow this every session)

1. **Orient:** read this file, then `context.md` (especially the latest execution log entries
   and open questions).
2. **Plan first:** for any task bigger than a one-line fix, write `plans/NNNN-short-name.md`
   using the shape in `plans/README.md` (Context / Decisions / Steps / Risks / Verification).
   Refine it with Kevin before touching code.
3. **Execute one step at a time.** After **every** step, add a dated entry to `context.md`'s
   execution log: what was actually done, files touched, how it was verified, and whether it
   deviated from the plan (say so explicitly if it did).
4. **Ask rather than guess** on product decisions, naming of money-related fields, schema
   changes, and anything irreversible.
5. **Never claim something works that hasn't been run.** "Type-checks / analyzer clean" is not
   "works". If you couldn't run it on a device or emulator, write that plainly in `context.md`
   ("not yet run on a device").
6. **Verify fixes by re-trying the failure,** not by re-reading the code.
7. **Prefer one shared helper over N copies** of the same logic.
8. **Every schema change** gets a new Drift schema version, a migration, and a migration test
   in the same change.

---

## 7. Git conventions

- Branch per task: `feature/…`, `fix/…`, `docs/…`, `chore/…`.
- Conventional Commits: `feat: …`, `fix: …`, `docs: …`, `test: …`, `refactor: …`, `chore: …`.
- **No AI co-author trailers.** Never add `Co-Authored-By: Claude …` or any AI attribution to
  commits, PR titles or PR descriptions. This overrides default tooling behaviour.
- Always create new commits; don't amend or force-push shared branches.
- Don't push or open PRs unless Kevin asks in that session.
- Never commit: `context.md`, `plans/`, `.env*`, `google-services.json`,
  `GoogleService-Info.plist`, keystores, or any secret.

---

## 8. Security and privacy

- Records belong to real people's savings groups. Store only name and optional phone.
  No national ID numbers, no location.
- Database to be encrypted with SQLCipher, key in `flutter_secure_storage` (Android Keystore).
  **Not done yet:** planned for after the talk, so the demo build is not encrypted. Say so
  when showing it, and never put real savings records in a demo build.
- No secrets in source, `context.md` or plans. Config comes from `--dart-define` or local,
  gitignored files. Document how contributors create their own.
- Exclude the database from Android auto-backup.

---

## 9. Writing style for code and docs

- Code is read by beginners at a conference and by first-time contributors. Name things
  plainly, keep functions short, comment the *why*, not the *what*.
- User-facing strings go in ARB files, never hard-coded, so translation is an easy contribution.
- Docs in plain English, short sentences. No marketing language.
