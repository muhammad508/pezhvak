package ir.fastflutter.pezhvak

import android.app.NotificationManager
import android.content.Context
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/** For "silent" rules: shows a quiet notification (no sound or vibration) instead of an alarm. */
object SilentMatchNotifier {
    private const val TAG = "SilentMatchNotifier"
    private const val CHANNEL_ID = "SilentMatchChannel"
    private const val GROUP = "pezhvak_silent_matches"
    private const val FIRST_ID = 3000
    private const val ID_RANGE = 100_000

    // Flutter's shared_preferences plugin stores its values here, prefixed with "flutter.".
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val FLUTTER_KEY_SHOW_DETAILS = "flutter.show_notification_details"
    private const val FLUTTER_KEY_SHOW_APP = "flutter.show_source_app"

    fun post(context: Context, appName: String, title: String, text: String) {
        try {
            val nm = NotificationManagerCompat.from(context)
            if (!nm.areNotificationsEnabled()) return

            // Honour the same "show text / show app" settings as the alarm screen.
            val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val showDetails = flutterPrefs.getBoolean(FLUTTER_KEY_SHOW_DETAILS, true)
            val showApp = flutterPrefs.getBoolean(FLUTTER_KEY_SHOW_APP, true)

            NotificationSupport.ensureChannel(
                context, CHANNEL_ID, R.string.silent_channel_name,
                NotificationManager.IMPORTANCE_LOW, R.string.silent_channel_description
            ) {
                setSound(null, null)
                enableVibration(false)
            }

            val heading = if (showApp) appName else context.getString(R.string.silent_unknown_app)
            val body = if (showDetails) {
                listOf(title, text).filter { it.isNotBlank() }.joinToString("\n")
            } else {
                context.getString(R.string.silent_text_hidden)
            }
            val id = FIRST_ID + (System.currentTimeMillis() % ID_RANGE).toInt()
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pezhvak)
                .setContentTitle(heading)
                .setContentText(body.lineSequence().first())
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setGroup(GROUP)
                .setAutoCancel(true)
                .setContentIntent(NotificationSupport.openAppIntent(context, id))
                .build()
            @Suppress("MissingPermission") // Guarded by areNotificationsEnabled() above.
            nm.notify(id, notification)
        } catch (e: Exception) {
            Log.e(TAG, "post failed: $e")
        }
    }
}
