/// Mutable state shared by the entry point, the permission gate and the alarm screen.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Packages of the apps the user selected for monitoring.
Set<String> selectedApps = {};

/// Local notifications plugin used for permission requests and initialization.
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Player for the alarm sound; replaced after every dismissed alarm.
AudioPlayer alarmPlayer = AudioPlayer();

/// Path of the alarm sound picked by the user, or null for the bundled default.
String? selectedAudioPath;

/// True while the alarm sound is playing.
bool isAlarmPlaying = false;

/// Payload of the alarm that launched the app, or null on a normal launch.
Map<String, dynamic>? pendingAlarm;
