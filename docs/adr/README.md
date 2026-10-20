# Architecture Decision Records

Each file records one significant decision: the context, what we chose, and the consequences.
They're short on purpose. Don't edit an accepted ADR to change the decision — write a new one
that supersedes it and link back.

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-append-only-ledger.md) | Ledger entries are append-only | Accepted |
| [0002](0002-vendors-behind-ledgerremote.md) | All backends behind `LedgerRemote` | Accepted |
| [0003](0003-flutter-drift-riverpod.md) | Flutter + Drift + Riverpod as the local-first core | Accepted |

## Template

```markdown
# NNNN. Title

Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded by NNNN

## Context
What problem or force led to this decision.

## Decision
What we chose, stated plainly.

## Consequences
What gets easier, what gets harder, what we must now do.
```
