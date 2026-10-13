## What this changes

<!-- One or two sentences. Link the issue: "Closes #123". -->

## How I tested it

<!-- Commands you ran, and what you checked on a device or emulator. -->

- [ ] `dart format .`
- [ ] `flutter analyze` (no issues)
- [ ] `flutter test`
- [ ] Still runs with `--dart-define=BACKEND=fake`

## Screenshots

<!-- For UI changes. Delete if not relevant. -->

## Checklist

- [ ] No network calls from screens or widgets
- [ ] Writes go to the table and the outbox in one transaction
- [ ] No updates or deletes on ledger entries
- [ ] Money stored as `int` shillings
- [ ] New text is in ARB files
- [ ] Schema change? Migration and migration test added
