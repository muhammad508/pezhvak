/// Names of the platform method channels shared with the Kotlin side (see `MainActivity`).
abstract final class AppChannels {
  /// Starts and stops the foreground monitoring service.
  static const String service = 'ir.fastflutter.pezhvak/service';

  /// Diagnostics, service status, device info and manufacturer-specific settings.
  static const String system = 'ir.fastflutter.pezhvak/system';

  /// Reads and writes the keyword and title lists consumed by the native listener.
  static const String files = 'ir.fastflutter.pezhvak/files';
}
