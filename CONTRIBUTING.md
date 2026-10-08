# Contributing

Thanks for taking a look at Pezhvak. The code is published for viewing only (see [LICENSE](LICENSE)),
so please open an issue before sending a pull request. This page explains how to build the project
and what a good change looks like.

## Setup

```bash
flutter pub get
```

Secrets are never committed. Without them the app still builds and runs; in-app purchases are
simply disabled. See "Build-time configuration" in the [README](README.md) to add your own.

## Checks to run before opening a pull request

```bash
dart format --output=none --set-exit-if-changed lib test   # formatting
flutter analyze                                            # lints, must be clean
flutter test                                               # Dart unit tests
(cd android && ./gradlew :app:testDebugUnitTest)           # Kotlin unit tests
```

CI runs the same checks.

## Conventions

- **Language:** code, comments, commit messages and documentation are in English. Text shown to
  the user is Persian; native strings live in `android/app/src/main/res/values/strings.xml`.
- **Structure:** Dart code is grouped by role (`core`, `services`, `pages`, `widgets`, `utils`);
  Kotlin files have one responsibility each. Keep pure logic separate from widgets and Android
  APIs so it can be unit-tested.
- **Shared files:** the Dart and Kotlin sides read and write the same JSON files. Rename a file or
  a preference key on both sides, or on neither (`StorageFiles`, `AppPrefs`).
- **Do not rename** `MyNotificationListenerService`: the notification-access grant of existing
  users is tied to its component name.
- **Commits:** short imperative subject (for example `Add negative words to rule options`),
  following [Conventional Commits](https://www.conventionalcommits.org) is welcome but optional.
- **Secrets:** never commit keystores, `key.properties`, `dart_defines.json`, API keys or personal
  paths. If you do by accident, rotate the secret first, then remove it from history.

## Reporting problems

Bugs and ideas go to the issue tracker. Security problems do not: follow
[SECURITY.md](SECURITY.md) instead.
