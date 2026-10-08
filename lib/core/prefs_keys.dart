/// Keys of the Flutter-side SharedPreferences.
abstract final class PrefsKeys {
  /// Whether monitoring is on. Mirrored natively in `MyAppPrefs` by the foreground-service channel.
  static const String serviceEnabled = 'service_enabled';

  /// Show the notification title and text on the alarm screen. Also read natively (as `flutter.<key>`) for silent matches.
  static const String showNotificationDetails = 'show_notification_details';

  /// Show the sending app on the alarm screen. Also read natively (as `flutter.<key>`) for silent matches.
  static const String showSourceApp = 'show_source_app';

  /// Path of the alarm sound picked by the user.
  static const String alarmAudio = 'alarm_audio';

  /// The user already opened the Myket rating page.
  static const String myketRated = 'myket_rated';

  /// How many times the home page was opened (drives the rating prompt).
  static const String appOpenCount = 'app_open_count';

  /// Expiry date for which the "subscription ended" dialog was already shown.
  static const String premiumExpiryNotified = 'premium_expiry_notified';

  /// Expiry date for which the "expires soon" reminder was already shown.
  static const String premiumExpirySoonNotified =
      'premium_expiry_soon_notified';
}
