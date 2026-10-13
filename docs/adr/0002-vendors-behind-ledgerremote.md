# 0002. All backends behind `LedgerRemote`

Date: 2026-10-11
Status: Accepted

## Context
Cloud services change prices, change terms, restrict regions or shut down. For example, MongoDB
deprecated Realm's Atlas Device Sync in September 2024 with end-of-life in September 2025; apps
with Realm types spread through their code faced rewrites. Costs billed in US dollars also rise
when the shilling falls.

## Decision
The app depends on one Dart interface we own:

```dart
abstract interface class LedgerRemote {
  Future<PushResult> push(List<OutboxItem> items);
  Future<List<LedgerEntry>> pullSince(String groupId, DateTime since);
}
```

Each backend (PocketBase, Firebase, Fake, later Supabase) is one class in `lib/remote/`. Vendor
packages may only be imported there; CI fails otherwise. The backend is chosen by one Riverpod
provider, driven by `--dart-define=BACKEND`.

## Consequences
- Switching backends is a one-line change; the UI, database and sync logic don't change.
- A `FakeLedgerRemote` lets anyone develop and test with no server.
- Adapters must map vendor data to our own types; vendor types never leak out.
- We can't use vendor-specific features (e.g. real-time listeners) in core code without adding them
  to the interface first — a deliberate cost.
