# Ledger for Android and iOS

The Flutter app uses the same Supabase accounts and budget snapshots as the web app. It supports month-by-month plans, transactions, savings goals, annual reports and Ledger JSON backups. Ledger works in South African rand and uses Johannesburg time for the current month.

## Run and test

From this directory, using Flutter 3.50 or newer:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The app uses the public Supabase settings from the live site. To use a test or self-hosted project, pass `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` to the Flutter run or build command. Apply the repository migration to that project. For email confirmation, configure the project's Site URL to the web app. Never pass a service role or secret key.

## Android APK

```sh
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The release-mode APK uses the local debug signing key for sideloading and device testing. Configure a signing key for store distribution.

## iOS

On macOS with Xcode, run `flutter build ios --simulator` to build for the simulator. For a physical device or TestFlight, set an Apple Developer Team in the Runner project and configure signing.

## Backups and sync

Ledger saves edits automatically. A revision conflict keeps pending edits in the app. In **More → History**, export a JSON backup before reloading the cloud budget. Importing a backup replaces the workspace after confirmation.
