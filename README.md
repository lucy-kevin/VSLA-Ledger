# VSLA Ledger

An open-source, **offline-first** Flutter app for Village Savings and Loan Associations.

A treasurer records weekly savings, loans and repayments on a phone — even with no signal.
Records are saved on the phone first and sync to a server when a connection appears. Nothing
is lost, and no single cloud company owns the data.

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

You need Flutter 3.38.9 (stable channel) and an Android device or emulator. The app is
Android only for now: background sync and the backup settings are Android code.
Check your work with `dart format .`, `flutter analyze` and `flutter test`.

### Run with a real backend

**PocketBase** (open source, you run it yourself): see
[`server/pocketbase/README.md`](server/pocketbase/README.md), then

```bash
flutter run --dart-define=BACKEND=pocketbase --dart-define=PB_URL=http://10.0.2.2:8090
```

`10.0.2.2` is the Android emulator's name for your computer. On a real phone, use your
computer's IP address on the same Wi-Fi.

**Firebase** (Google's cloud, here for comparison): see
[`server/firebase/README.md`](server/firebase/README.md), then

```bash
flutter run --dart-define=BACKEND=firebase
```

### Talk demo settings

`--dart-define=DEMO=true` adds a Compare screen that saves the same record two ways (on the
phone first, or waiting for the server) and times both. `--dart-define=DEMO_DELAY_MS=3000`
makes every server request wait 3 seconds, to show a slow network.

## How it works

- The phone's SQLite database (via [Drift](https://drift.simonbinder.eu/)) is the source of truth.
- Every change is written to the database **and** an outbox in one transaction.
- The app syncs after each save, when the network comes back, when you reopen it, every ~15
  minutes in the background (Android), and when you tap **Sync now**.
- Money records are **append-only**: a mistake is cancelled and the right amount recorded
  again, like crossing out a line in a paper ledger. The phone and the servers refuse edits.
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

**The database on the phone is not encrypted yet** (planned next). Use demo data only until it
is. Android backup of the database is switched off.

Please don't report security problems in public issues. See [SECURITY.md](SECURITY.md).

## Maintainers

Built by Research Code Respond — Kevin Ziyada Aseru and Julian Zaabu Kayikayi.
Contact: akevinziyada@researchcoderespond.org.

## Licence

[MIT](LICENSE).
