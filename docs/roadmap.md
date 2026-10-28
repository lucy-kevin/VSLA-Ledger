# Roadmap: what is not built yet

Each item below is written so it can become a GitHub issue. Items marked **good first issue** need
no deep knowledge of the sync code. Read [architecture.md](architecture.md) first.

## Needs a real savings group first

These need someone who runs a VSLA to say what is right, before any code.

- **Check the loan charge rules.** The app charges a percent each month on what is unpaid,
  paid before the loan. Real groups may charge differently (up front, on the whole balance, a
  fixed amount). See [ADR 0004](adr/0004-loan-charge-computed-not-stored.md).
- **Share-out at the end of a cycle.** Work out each member's share of savings, charges and fines.
- **Group rules per cycle.** Share price and charge may change from one cycle to the next.

## Security and privacy

- **Login and roles.** Today anyone with the server address and a join code can read and write a
  group. A treasurer, a secretary and read-only members are the usual roles. Needs server rules
  for PocketBase and Firestore.
- **Encrypt the database on the phone** (SQLCipher through `sqlite3` 3.x, key in
  `flutter_secure_storage`).
- **Show who recorded each entry.** `deviceId` is stored but not shown.
- **App lock** (PIN) for a shared phone.

## Product

- **Edit a member** (name, phone). Groups and members sync as insert-or-ignore today, so this
  needs last-write-wins on `updatedAt`. **good first issue** for the screen, the sync part is bigger.
- **Edit group rules** (charge, share price), with the same sync work.
- **Group report** for one meeting or one month (savings, loans out, charges, fines), shareable
  as text or PDF.
- **Search and sort** members. **good first issue**
- **Luganda** and other languages: copy `lib/l10n/app_en.arb` to `app_lg.arb` and translate.
  **good first issue**
- **Large text and screen reader pass** on every screen. **good first issue**

## Sync and platform

- **Phone-to-phone sharing** with no server, behind a `PeerSync` interface.
- **Supabase adapter** behind `LedgerRemote`, as another example of swapping a backend.
- **iOS and web.** The app is Android only today: background sync and the backup settings are
  Android code.
- **Keep refused records from piling up:** a screen to see records the server refused and retry
  or export them.
