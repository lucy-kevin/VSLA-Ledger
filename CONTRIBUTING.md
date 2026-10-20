# Contributing to VSLA Ledger

Thank you for helping. You don't need to be an expert: docs, translations, design, testing
and bug reports are all real contributions, and all get credited.

If anything here is unclear, that's a bug in this file — please open an issue.

## 1. Find something to work on

- Issues labelled **`good first issue`** are small and clearly described.
- **`translation`** — add or improve a language in `lib/l10n/`. No Dart knowledge needed.
- **`docs`**, **`design`**, **`help wanted`** — exactly what they say.
- Want to work on something else? Open an issue first so we can agree on the approach before
  you spend time on it.

Comment on an issue to say you're taking it, so two people don't do the same work.

## 2. Set up

You need: Flutter (stable channel), Git, and an Android device or emulator.
No laptop powerful enough? GitHub Codespaces works for editing, `flutter analyze` and tests.

```bash
git clone https://github.com/<owner>/vsla_ledger.git
cd vsla_ledger
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=BACKEND=fake
```

The `fake` backend runs everything on your phone with no server and no internet. You only need
PocketBase or Firebase if you're working on those adapters (see `server/pocketbase/README.md`).

## 3. The rules that matter

These keep the app local-first and easy to change. CI checks most of them.

1. Screens read data only from the local database (Drift `watch()` streams). Never call the
   network from a widget.
2. Every write goes to its table **and** the `outbox` in one transaction.
3. Ledger entries are **never edited or deleted**. Fix mistakes with a correction entry.
4. Money is whole shillings in `int`. Never `double`.
5. Backend packages (`pocketbase`, `cloud_firestore`, `supabase_flutter`, …) are imported only
   in `lib/remote/`.
6. User-facing text goes in ARB files, not in code.
7. `flutter run --dart-define=BACKEND=fake` must always work.

Why these rules exist: [docs/architecture.md](docs/architecture.md) and [docs/adr/](docs/adr/).

## 4. Make your change

```bash
git checkout -b feature/short-description     # or fix/…, docs/…
# … make changes …
dart run build_runner build --delete-conflicting-outputs   # if you changed models, providers or tables
dart format .
flutter analyze
flutter test
```

All four must pass before you open a pull request. If you changed the database schema, add a
migration **and** a migration test.

### Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add repayment screen
fix: show correct balance after correction
docs: explain outbox in architecture.md
test: cover failed push retry
```

## 5. Open a pull request

- Fill in the pull request template.
- Keep it focused: one change per PR is easier to review.
- Add screenshots for UI changes.
- CI must pass. If it fails, the log says why — ask in the PR if you're stuck.

### What review looks like

A maintainer will review within a few days. Reviews are about the code, never about you.
Expect questions and suggestions; that's normal, not a sign you did something wrong.
Once approved and CI is green, a maintainer merges it.

## 6. Recognition

Every contributor is credited in the README via the all-contributors bot — code, docs,
translation, design, testing and ideas all count.

## 7. Behaviour

Everyone taking part follows our [Code of Conduct](CODE_OF_CONDUCT.md).
