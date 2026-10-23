# Running PocketBase locally

PocketBase is a single-file, open-source backend. You only need it if you're working on the
PocketBase adapter or testing real sync. Everything else works with `BACKEND=fake`.

Tested with **PocketBase 0.40.5**.

1. Download PocketBase 0.40.5 for your OS from
   https://github.com/pocketbase/pocketbase/releases/tag/v0.40.5 and put the `pocketbase`
   (or `pocketbase.exe`) file in this folder. It's gitignored. Check it against the release's
   `checksums.txt`.
2. Start it from this folder:

   ```bash
   ./pocketbase serve --http=0.0.0.0:8090
   ```

   The first start creates the `groups`, `members` and `ledger_entries` collections for you,
   from `pb_migrations/`. There is nothing to import.
3. Optional: to look at the data, create a local admin and open http://127.0.0.1:8090/_/

   ```bash
   ./pocketbase superuser upsert admin@vsla.test <a-password-you-make-up>
   ```

   Keep that password in `.env.local` in this folder (gitignored), never in a commit.
4. Run the app against it:

   ```bash
   # Android emulator
   flutter run --dart-define=BACKEND=pocketbase --dart-define=PB_URL=http://10.0.2.2:8090
   # Real phone on the same Wi-Fi or hotspot: use your laptop's IP
   flutter run --dart-define=BACKEND=pocketbase --dart-define=PB_URL=http://192.168.x.x:8090
   ```

Local data lives in `pb_data/` (gitignored). Delete it to start fresh.

## What the server enforces

- Record ids are the UUIDs the phones make. The server never makes an id.
- Amounts are whole shillings, at least 1.
- Ledger entries are append-only: sending the same entry again is fine (that's a retry);
  changing or deleting one is refused.
- Entry types are `contribution`, `loan`, `repayment`, `correction`, `socialFund` and `fine`.
  Shares and a loan's monthly charge are whole numbers and cannot change after an entry is saved.

The second migration (`1792800000_add_meetings_charges_shares.js`) adds meeting dates, shares,
the monthly loan charge, the share price, and the two new entry types. PocketBase applies it by
itself when it starts. **An app from before this change cannot sync to a server that has not
run it, and the other way round.** If the app says records were refused, check the server has
started since you updated the repository.

## Demo only

The access rules let **anyone who can reach the server** read and write. That's fine on your
own laptop or phone hotspot with demo data. Never run it like this on a public network or
with real savings records. Adding login is a good first issue.
