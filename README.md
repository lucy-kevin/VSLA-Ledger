# VSLA Ledger

An open-source, **offline-first** Flutter app for Village Savings and Loan Associations.

A treasurer records weekly savings, loans and repayments on a phone — even with no signal.
Records are saved on the phone first and sync to a server (or straight to another phone)
when a connection appears. Nothing is lost, and no single cloud company owns the data.

> Status: early development. Built as the live demo for the droidcon Uganda 2026 talk
> *"Building for Ourselves: Why Open Source and Local-First Mobile Apps Matter for African
> Developers"*. Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Why

- **Data costs money.** Every unnecessary network call costs users airtime.
- **Connectivity is uneven.** Apps that need a live connection fail exactly where they're needed.
- **Vendors change.** Prices change, products shut down. This app keeps every backend behind
  one small interface, so switching is one line, not a rewrite.

## Run it in three commands (no server needed)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=BACKEND=fake
```

You need Flutter (stable channel) and an Android device or emulator.

### Run with a real backend (PocketBase)

See [`server/pocketbase/README.md`](server/pocketbase/README.md), then:

```bash
flutter run --dart-define=BACKEND=pocketbase --dart-define=PB_URL=http://10.0.2.2:8090
```

## How it works

- The phone's SQLite database (via [Drift](https://drift.simonbinder.eu/)) is the source of truth.
- Every change is written to the database **and** an outbox in one transaction.
- A sync service pushes the outbox and pulls new records when a network is available.
- Money records are **append-only**: mistakes are fixed with a correction entry, like a paper ledger.
- Backends (PocketBase, Firebase, a fake one for development) all implement one Dart interface,
  `LedgerRemote`.

Full details: [docs/architecture.md](docs/architecture.md) and the decision records in
[docs/adr/](docs/adr/).

## Contributing

New here? Look for issues labelled
[`good first issue`](../../issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).
Translations (Luganda and others), docs, design and tests are all valued contributions.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) and our [Code of Conduct](CODE_OF_CONDUCT.md).

## Security

Please don't report security problems in public issues. See [SECURITY.md](SECURITY.md).

## Maintainers

Built by [Research Code Respond](#) — Kevin Ziyada Aseru and Julian Zaabu Kayikayi.

## Licence

To be decided before the first public release (MIT or Apache-2.0).
