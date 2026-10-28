/// <reference path="../pb_data/types.d.ts" />

// Version 2 of the app adds meetings, loan service charge, shares, social
// fund and fines. This adds the fields and entry types they need.
//
// PocketBase runs it automatically the next time it starts. Old records are
// untouched: every new field is optional.

migrate((app) => {
  const groups = app.findCollectionByNameOrId("groups");
  // Percent charged each month on what is still owed on a loan. 0 = none.
  groups.fields.add(new NumberField({
    name: "monthlyChargePercent", onlyInt: true, min: 0, max: 100,
  }));
  // Whole shillings for one share. Empty or 0 = the group saves amounts.
  groups.fields.add(new NumberField({
    name: "sharePriceUgx", onlyInt: true, min: 0,
  }));
  app.save(groups);

  const entries = app.findCollectionByNameOrId("ledger_entries");
  // The day of the meeting an entry belongs to (not the time it was typed).
  entries.fields.add(new DateField({ name: "meetingDate" }));
  entries.fields.add(new NumberField({
    name: "shares", onlyInt: true, min: 0,
  }));
  // On a loan: the group's monthly charge when the loan was given.
  entries.fields.add(new NumberField({
    name: "monthlyChargePercent", onlyInt: true, min: 0, max: 100,
  }));
  entries.fields.getByName("type").values = [
    "contribution", "loan", "repayment", "correction", "socialFund", "fine",
  ];
  // Still append-only: the two new money fields may not change either.
  entries.updateRule = [
    "@request.body.groupId = groupId",
    "@request.body.memberId = memberId",
    "@request.body.type = type",
    "@request.body.amountUgx = amountUgx",
    "@request.body.correctsEntryId = correctsEntryId",
    "@request.body.loanId = loanId",
    "@request.body.shares = shares",
    "@request.body.monthlyChargePercent = monthlyChargePercent",
  ].join(" && ");
  app.save(entries);
}, (app) => {
  const groups = app.findCollectionByNameOrId("groups");
  groups.fields.removeByName("monthlyChargePercent");
  groups.fields.removeByName("sharePriceUgx");
  app.save(groups);

  const entries = app.findCollectionByNameOrId("ledger_entries");
  entries.fields.removeByName("meetingDate");
  entries.fields.removeByName("shares");
  entries.fields.removeByName("monthlyChargePercent");
  entries.fields.getByName("type").values = [
    "contribution", "loan", "repayment", "correction",
  ];
  app.save(entries);
});
