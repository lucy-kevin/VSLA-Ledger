# Using Firebase (Cloud Firestore)

Firebase is here to **compare** with PocketBase: the same app on a vendor's cloud instead of
your own server. You only need it to try `BACKEND=firebase`. Everything else works with
`BACKEND=fake` and no account.

Firebase config is private to each developer, so it is never in the repo. Make your own:

1. In the [Firebase console](https://console.firebase.google.com/), create a project (the free
   Spark plan is enough).
2. **Add an Android app** with package name `com.vsla.vsla_ledger`. Skip the SHA-1 and skip the
   "Add Firebase SDK" Gradle step (the repo already has it).
3. Download `google-services.json` and put it at `android/app/google-services.json`. It is
   gitignored. The build only uses Firebase when this file is there.
4. **Firestore Database → Create database.** Pick the location closest to your users (we use
   `africa-south1`, Johannesburg; it can't be changed later). Start in **production mode**.
5. **Rules:** open the Rules tab, replace everything with [`firestore.rules`](firestore.rules),
   and press **Publish**. Until you do, production mode refuses every read and write.
6. **Indexes:** open the Indexes tab and add the two composite indexes in
   [`firestore.indexes.json`](firestore.indexes.json): collection `members`, then
   `ledger_entries`, each with fields `groupId` ascending and `serverUpdatedAt` ascending.
   (Or, with the Firebase CLI: `firebase deploy --only firestore:indexes`.) If you skip this,
   the first pull fails with an error that contains a link to create the index.
7. Run:

   ```bash
   flutter run --dart-define=BACKEND=firebase
   ```

## Things worth knowing

- Firestore's own offline cache is **switched off** in this app. Firestore can do offline
  writes by itself, but then Firestore owns how your data is stored on the phone. We want the
  outbox (and the lesson) to be ours.
- With the cache off, Firestore waits for the network instead of failing, so the app gives each
  request 20 seconds before counting it as failed and trying again later.
- The rules make ledger entries append-only on the server too: a retried push is accepted,
  a changed or deleted entry is refused.

## Demo only

The rules let anyone who has the app's config read and add records. Use demo data only.
Adding login is a good first issue.
