# Changelog

All notable changes are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `LICENSE` (all rights reserved). The default alarm sound `assets/audio.mp3` was removed from the public
  repository for licensing reasons; see `assets/README.md`.
- Per-rule advanced options for premium users: priority (urgent, normal, silent), custom sound,
  vibration, repeat until acknowledged, negative words and a dedicated schedule.
- Premium history tools: date-range filter, CSV export and a "triggered by" label.
- Test alarm, daily summary notification and a live service-health banner (all users).
- Stability diagnostics screen (process exit reasons, crashes, listener events) and a
  background-survival guide per phone brand.
- Kotlin and Dart unit tests, CI, and `SECURITY.md` / `CONTRIBUTING.md`.

### Changed
- Notification history is stored as append-only JSONL and processed off the main thread; free
  users see the last 10 records, premium users up to 10,000.
- The foreground service uses the `specialUse` type on Android 14+, which has no runtime cap
  (the former `dataSync` type is killed after about six hours on Android 15).
- Release signing and the Myket public key are provided at build time instead of being committed.
- Android backup is disabled so notification content is not copied to the cloud.
- The subscription state is exposed as one listenable (`PremiumService.status`) instead of being
  passed through the widget tree.

### Fixed
- A custom alarm sound whose file disappeared made the alarm silent; the bundled sound is now the
  fallback and picked sounds are copied into app storage.
- The legacy history file was never migrated to the JSONL format on the first run after an update.
- Several `setState` calls after an `await` ran without checking `mounted`.
