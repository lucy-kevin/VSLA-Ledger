# 0001. Ledger entries are append-only

Date: 2026-10-11
Status: Accepted

## Context
Several phones (treasurer, secretary) record entries offline and sync later. If entries could be
edited or deleted, two phones changing the same entry offline would conflict, and one change
would be silently lost. Savings groups also need a trustworthy history: members must be able to
see that a record wasn't quietly changed.

## Decision
`ledger_entries` rows are never updated or deleted. A mistake is fixed by inserting a new entry of
type `correction` with `correctsEntryId` pointing at the original. Balances are always calculated
from entries, never stored.

## Consequences
- Two devices adding entries never collide; merging is "insert what I don't have".
- Full audit trail for free.
- Balance queries must account for corrections; these need tests.
- The table grows forever. Fine for a group's lifetime of weekly meetings; revisit archiving only
  if real data shows a problem.
- `LedgerDao` must not expose update or delete methods.
