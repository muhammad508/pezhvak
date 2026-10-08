# Pezhvak (پژواک)

Pezhvak watches your Android notifications and raises a full-screen alarm when
an important one arrives: a keyword in the text, a phrase in the title, or any
notification from an app you selected. The alarm shows over the lock screen and
monitoring keeps running in the background.

The user interface is in Persian (RTL). Code, comments and documentation are in English.

> **Platform:** Android only (`minSdk 26`, `targetSdk 35`). The app relies on Android's
> `NotificationListenerService`, so the other Flutter platforms are intentionally not included.

## Features

| Free | Premium |
| --- | --- |
| Alarm on keywords, titles and selected apps | Per-rule priority (urgent / normal / silent), sound and vibration |
| Full-screen alarm over the lock screen | Negative words per rule (for example, ignore "discount code") |
| Notification history (last 10 records) | Per-rule schedule, even outside the global schedule |
| Test alarm, daily summary, live service-health banner | Repeat the alarm until it is acknowledged |
| Background-survival guide per phone brand | Notification and alarm history up to 10,000 records, date filter, CSV export, "triggered by" label |
| Stability diagnostics (why did the process die?) | Global time and day schedule |

Premium is sold through [Myket](https://myket.ir) subscriptions.

## Architecture

```
lib/
  main.dart            Entry point: initialization, then the permission gate
  app.dart             MyApp: themes, premium sync, alarm-vs-home routing
  core/                Theme, shared state, storage file names, SharedPreferences keys, channel names
  services/            Persistence, custom sound storage, platform channels, Myket purchases
  pages/               Screens (home, alarm, histories, rules, schedule, ...)
  widgets/             Reusable widgets (home widgets, history cards, rule options sheet)
  utils/               Pure helpers (history filtering, CSV, week days)

android/app/src/main/kotlin/ir/fastflutter/pezhvak/
  MyNotificationListenerService   Receives notifications, matches rules, fires alarms
  MonitoringForegroundService     Keeps the process alive (specialUse on Android 14+)
  RestartReceiver                 15-minute watchdog tick and restart after boot
  ServiceWatchdog                 Detects a dead listener, rebinds, alerts the user
  AlarmLauncher / RepeatAlarm     Opens the alarm screen; repeat-until-acknowledged
  HistoryStore / JsonFileCache    Append-only JSONL history and cached config files
  DailySummary / DiagnosticsLog   Daily summary notification; exit-reason diagnostics
```

The Dart UI and the native listener share data through JSON files in the app's
files directory (keywords, titles, selected apps, schedule, rule options, history).
Writes are atomic (temp file + rename) so neither side reads a half-written file.

## Getting started

Requirements: Flutter (stable channel, Dart `^3.6.1`), JDK 17 and the Android SDK (API 36).

```bash
flutter pub get
flutter analyze
flutter test
```

### Build-time configuration

Secrets are never committed. Copy the examples and fill in your own values:

| Template | Copy to (git-ignored) | Purpose |
| --- | --- | --- |
| `dart_defines.example.json` | `dart_defines.json` | `MYKET_RSA_KEY`: your app's Myket public RSA key |
| `android/key.properties.example` | `android/key.properties` | Release signing (keystore path and passwords) |

```bash
cp dart_defines.example.json dart_defines.json
flutter run --dart-define-from-file=dart_defines.json
```

Without `MYKET_RSA_KEY` the app runs normally, but in-app purchases are disabled.

The default alarm sound is not included in the repository (licensing); see
[assets/README.md](assets/README.md) to add your own.

### Release build

1. Create a keystore and keep it **out of git**:
   ```bash
   keytool -genkey -v -keystore android/app/release-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Fill in `android/key.properties` (`storeFile` is relative to `android/app`).
3. Build:
   ```bash
   flutter build apk --release --dart-define-from-file=dart_defines.json
   ```

If `android/key.properties` is missing, the release build is signed with the debug key so
that anyone can build the project. **Never publish such a build.**

## Permissions and privacy

Pezhvak needs sensitive permissions because of what it does. Everything stays on the device.

| Permission | Why |
| --- | --- |
| Notification access (`BIND_NOTIFICATION_LISTENER_SERVICE`) | Read incoming notifications to match rules |
| Foreground service (`specialUse`) | Keep monitoring alive in the background |
| Draw over other apps, full-screen intent, wake lock | Show the alarm over the lock screen |
| Exact alarms | Watchdog restarts and repeat alarms |
| Ignore battery optimizations | Stop the system from killing the service |
| Post notifications | Service-health warnings, daily summary, silent matches |

- Notification content is stored locally in `notification_history.jsonl` and `alarm_history.jsonl`
  (up to 10,000 records each). It can include sensitive text such as one-time codes.
  Android backup is disabled so this data is not copied to the cloud.
- The app's own manifest does not declare the `INTERNET` permission.
- See [SECURITY.md](SECURITY.md) for the security model and how to report a vulnerability.

## Vendored plugin

`notification_listener_service-0.3.4/` is the upstream
[`notification_listener_service`](https://pub.dev/packages/notification_listener_service) plugin,
included in the repository and referenced by path. The only change is in
`android/build.gradle`: the Android Gradle Plugin classpath is bumped from `7.4.1` to `8.1.0`
so the plugin builds with the project's current toolchain. Its original `LICENSE` is kept, and it
is excluded from static analysis.

## Testing

```bash
flutter test
```

Dart unit tests cover rule option serialization, history filtering, timestamp formatting and CSV
export. Kotlin unit tests (`cd android && ./gradlew :app:testDebugUnitTest`) cover the config
file cache, the JSONL history store (including migration and trimming) and rule parsing.
The notification listener and the alarm flow need a device; the in-app
**Test alarm** button and the **Stability report** screen help verify them on real hardware.

## Known limitations

- **The UI is Persian-only and hard-coded.** Native notification texts live in
  `android/app/src/main/res/values/strings.xml`; the Dart side does not use ARB localization yet.
- **Only pure logic has unit tests.** There are no widget or integration tests; the alarm flow
  needs a device.
- The Persian UI font (Vazir) is not bundled, so the system font is used.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the checks to run and the conventions used here, and
[CHANGELOG.md](CHANGELOG.md) for what changed.

## License

All rights reserved. The code is published for viewing only; see [LICENSE](LICENSE).
The vendored plugin keeps its own license.
