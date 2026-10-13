# Running PocketBase locally

PocketBase is a single-file, open-source backend. You only need it if you're working on the
PocketBase adapter or testing real sync. Everything else works with `BACKEND=fake`.

1. Download the PocketBase binary for your OS from https://pocketbase.io/docs/ and put it in this
   folder (it's gitignored).
2. Start it:

   ```bash
   ./pocketbase serve
   ```

3. Open http://127.0.0.1:8090/_/ and create a local admin account (keep the password to yourself).
4. Import the collections: **Settings → Import collections** → paste `pb_schema.json`
   (added once the adapter exists).
5. Run the app against it:

   ```bash
   # Android emulator
   flutter run --dart-define=BACKEND=pocketbase --dart-define=PB_URL=http://10.0.2.2:8090
   # Real phone on the same Wi-Fi: use your laptop's LAN IP
   flutter run --dart-define=BACKEND=pocketbase --dart-define=PB_URL=http://192.168.x.x:8090
   ```

Local data lives in `pb_data/` (gitignored). Delete it to start fresh.
