/// <reference path="../pb_data/types.d.ts" />

// Creates the three collections the app syncs: groups, members and
// ledger_entries. PocketBase runs this automatically the first time you
// start it, so there is nothing to import by hand.
//
// DEMO ONLY: the rules below let anyone who can reach this server read and
// write. Use it on your own hotspot or laptop, never on a public network.
// Adding login is a good first issue.

migrate((app) => {
  // The phone makes every id (a UUID v4), so the server must accept it as
  // the record id. PocketBase's own ids are 15 characters; ours are 36.
  // Never generate ids on the server: nothing should wait for one.
  const phoneMadeId = {
    name: "id",
    type: "text",
    system: true,
    primaryKey: true,
    required: true,
    min: 36,
    max: 36,
    pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    autogeneratePattern: "",
  };

  // `created` is when the server first received a record. `updated` is
  // what pulls ask for ("everything updated since my last pull").
  const serverClock = [
    { name: "created", type: "autodate", onCreate: true, onUpdate: false },
    { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
  ];

  const anyone = "";

  app.save(new Collection({
    type: "base",
    name: "groups",
    listRule: anyone,
    viewRule: anyone,
    createRule: anyone,
    updateRule: anyone,
    deleteRule: null,
    fields: [
      phoneMadeId,
      { name: "name", type: "text", required: true },
      { name: "joinCode", type: "text", required: true },
      { name: "createdAt", type: "date", required: true },
      { name: "updatedAt", type: "date", required: true },
      ...serverClock,
    ],
    indexes: [
      "CREATE INDEX idx_groups_join_code ON groups (joinCode)",
      "CREATE INDEX idx_groups_updated ON groups (updated)",
    ],
  }));

  app.save(new Collection({
    type: "base",
    name: "members",
    listRule: anyone,
    viewRule: anyone,
    createRule: anyone,
    updateRule: anyone,
    deleteRule: null,
    fields: [
      phoneMadeId,
      { name: "groupId", type: "text", required: true },
      { name: "name", type: "text", required: true },
      { name: "phone", type: "text" },
      { name: "joinedAt", type: "date", required: true },
      { name: "updatedAt", type: "date", required: true },
      ...serverClock,
    ],
    indexes: [
      "CREATE INDEX idx_members_group_updated ON members (groupId, updated)",
    ],
  }));

  app.save(new Collection({
    type: "base",
    name: "ledger_entries",
    listRule: anyone,
    viewRule: anyone,
    createRule: anyone,
    // Append-only on the server too. A phone that retries a push sends the
    // same entry again, which is allowed. Changing any money field of an
    // existing entry is refused: mistakes are fixed with a correction.
    updateRule: [
      "@request.body.groupId = groupId",
      "@request.body.memberId = memberId",
      "@request.body.type = type",
      "@request.body.amountUgx = amountUgx",
      "@request.body.correctsEntryId = correctsEntryId",
      "@request.body.loanId = loanId",
    ].join(" && "),
    deleteRule: null,
    fields: [
      phoneMadeId,
      { name: "groupId", type: "text", required: true },
      { name: "memberId", type: "text", required: true },
      {
        name: "type",
        type: "select",
        required: true,
        maxSelect: 1,
        values: ["contribution", "loan", "repayment", "correction"],
      },
      // Whole Uganda shillings, never a fraction, never below 1.
      { name: "amountUgx", type: "number", required: true, onlyInt: true, min: 1 },
      { name: "createdAt", type: "date", required: true },
      { name: "deviceId", type: "text", required: true },
      { name: "correctsEntryId", type: "text" },
      { name: "loanId", type: "text" },
      ...serverClock,
    ],
    indexes: [
      "CREATE INDEX idx_entries_group_updated ON ledger_entries (groupId, updated)",
    ],
  }));

  // The app sends up to 50 records in one request.
  const settings = app.settings();
  settings.batch.enabled = true;
  settings.batch.maxRequests = 50;
  app.save(settings);
}, (app) => {
  for (const name of ["ledger_entries", "members", "groups"]) {
    app.delete(app.findCollectionByNameOrId(name));
  }
});
