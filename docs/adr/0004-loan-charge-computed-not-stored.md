# 0004. The loan service charge is worked out when shown, never stored

Date: 2026-10-23
Status: Accepted

## Context
Real savings groups charge a service charge on loans. We chose a percentage per month of what is
still unpaid. The ledger is append-only (ADR 0001) and balances are never stored, so there is no
row to "add the interest to" each month. Phones also work offline, so nothing can wait for a
server to calculate it.

We have not yet had a real treasurer check these rules. They are the first version.

## Decision
- The group's monthly charge (percent, 0 to 100) is set when the group is made, and each loan
  copies it (`monthlyChargePercent`) when the loan is given. Changing a group later can never
  change an old loan.
- The charge is worked out from the loan, its repayments and today's date, in one place
  (`loanStatuses` in `lib/core/ledger/loan_status.dart`). It is never written to the database.
- A charge is added each time a full calendar month has passed since the loan's meeting day
  (a loan of 1 October gets its first charge on 1 November; a loan from the 31st is charged on
  the last day of a shorter month).
- A charge is the percentage of the loan still unpaid on that day, rounded to whole shillings,
  half up. Charges do not grow on charges.
- A repayment pays the charges first, then the loan. A repayment dated on a charge day counts
  before that charge is worked out.
- A repayment cannot be more than the loan plus the charges so far.
- The balance is also worked out in Dart from the entries (`computeBalance`). The SQL balance
  query was removed so the money rules exist once.

## Consequences
- No new entry type, no monthly job, nothing to sync for charges. Two phones with the same
  entries always show the same amount owed on the same day.
- Backdating a loan or a repayment changes the charges, which is right.
- The amount owed changes as days pass, even if nothing is recorded. The screens read the
  database again on every change and when the app comes back to the foreground, so a screen left
  open overnight can be a day behind until then.
- Group balances read every entry of the group into memory. Fine for 15 to 30 members; revisit
  if a group has years of weekly records.
- Someone on a different rule (charge on the whole balance, charge paid up front, interest
  compounding) needs a change to `_statusOf` and to this record, not a data migration.
- Not yet checked by a real treasurer.
