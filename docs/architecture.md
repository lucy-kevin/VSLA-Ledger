# Architecture

This page explains how VSLA Ledger works and why. Read it before your first non-trivial change.

## The one-line version

The phone's database is the real copy of the data. The server is a backup and a meeting point.
Only one small interface, `LedgerRemote`, ever talks to the network.

## Layers

```
Flutter screens (lib/features/)
        │  watch() streams              ▲
        ▼  user actions                 │ UI updates automatically
Riverpod controllers + repositories (lib/core/)
        │  one transaction
        ├──────────────► Drift tables (source of truth, append-only ledger)
        └──────────────► outbox table (changes waiting to sync)
                               │
                        SyncService (lib/core/sync/)
                               │ push and pull
                        LedgerRemote  ◄── the interface we own
                 ┌─────────────┼─────────────┐
           PocketBase      Firebase        Fake         (lib/remote/)
```

Phone-to-phone sharing (no server at all) was planned with its own interface, `PeerSync`
(`lib/peer/`), but is not built: a good project for a contributor.

## Writing a record

1. The user records, say, a UGX 10,000 contribution.
2. The repository creates a `LedgerEntry` with a UUID made on the phone.
3. In **one Drift transaction** it inserts the entry and adds an outbox item.
4. It asks the sync service to try a sync. If there's no network, nothing else happens — the
   record is already safe on disk.
5. The screen updates immediately, because it's watching the database, and shows
   **Saved on phone**.

## Syncing

`SyncService.run()` (only one at a time):

1. **Push:** send the outbox in batches of 50 through `LedgerRemote.push()`. Delete the ones the
   server accepted. Mark failures with `attempts` and `lastError` so they retry later. If the
   server refuses one record in a batch, the others are sent one by one so they still get through.
2. **Pull:** for each group, ask for records the server received since `lastPulledAt`. Insert
   any the phone doesn't have (skipped by id if already there). Save the new `lastPulledAt`,
   which comes from the **server's** clock, never the phone's.

A `SyncTrigger` starts it whenever something new lands in the outbox while online, when the
phone comes back online, and when the app comes back to the screen. A `workmanager` task runs
it about every 15 minutes in the background on Android, and the user can tap **Sync now**.
Entries leave the outbox → the badge changes to **Synced**.

## Why conflicts are rare

Money entries are **append-only**: nobody edits or deletes them. Two phones adding entries
offline never overwrite each other — merging is just "insert what I don't have". A mistake is
fixed by adding a `correction` entry that points to the original, exactly like a paper ledger.
Simple editable fields (a member's name) use last-write-wins on `updatedAt`.

Pushes are idempotent: the server upserts by id, so retrying after a timeout can't create duplicates.

## Choosing a backend

`lib/app/backend.dart` reads `--dart-define=BACKEND` (`fake`, `pocketbase`, `firebase`), and
`main.dart` overrides one Riverpod provider, `ledgerRemoteProvider`, with the result. Nothing else in the app knows which backend is in use.
Adding a new backend means writing one class in `lib/remote/` that implements `LedgerRemote`.

## Security

Done:

- Database excluded from Android backup and phone-to-phone transfer.
- Only name and optional phone stored per member. No ID numbers, no location.
- Ledger entries cannot be changed or deleted: the phone's database, PocketBase and the
  Firestore rules all refuse it.

Not done yet (planned after the first release):

- **Database encryption** with SQLCipher (via `sqlite3` 3.x), key in the Android Keystore via
  `flutter_secure_storage`. Until then, use demo data only.
- An app PIN on launch.
- Login on the servers. The demo PocketBase and Firestore rules let anyone read and add records.

## What stays online

This app records savings. It never moves real money. Anything that would move money must be
confirmed online by the payment provider, never assumed from the local database.

## Decision records

Big decisions are written up in [docs/adr/](adr/), so you can see *why* things are the way they are.
