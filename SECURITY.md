# Security policy

## Reporting a vulnerability

Please do **not** open a public issue for security problems. Use GitHub's
private vulnerability reporting instead: open the repository's **Security** tab and choose
**Report a vulnerability**. Include steps to reproduce and the Android version you tested on.

## Secrets

No secret may be committed to this repository. In particular:

- Release signing material (`*.jks`, `*.keystore`, `android/key.properties`) is git-ignored.
- Build-time configuration (`dart_defines.json`) is git-ignored; only `*.example` templates are tracked.
- If you ever commit a secret by accident, treat it as compromised: rotate it first, then
  remove it from history.

## Security model and known limitations

- **Data stays on the device.** Rules, history and the subscription cache are plain JSON files in
  the app's private storage. They are not encrypted at rest; anyone with root access or a
  debuggable build can read them. Android backup is disabled.
- **Premium state is enforced on the client.** The subscription expiry is cached in
  `premium.json` and checked locally (Dart and native). The authoritative source is Myket, which is
  re-queried on launch, but a rooted device could tamper with the local cache between checks.
  Robust protection would require server-side receipt validation, which this project does not have.
- **The notification listener sees every notification.** The app only matches and stores the
  content locally. Be careful when sharing history exports (CSV): they may contain private text.
- **File channel hardening.** The native file channel only reads and writes an allow-list of files
  (`keywords.json`, `titles.json`).
