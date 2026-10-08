package ir.fastflutter.pezhvak

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.annotation.StringRes

/** Small helpers shared by every component that posts notifications. */
internal object NotificationSupport {

    /** Creates the channel (a no-op when it already exists). [configure] can tweak sound, vibration, ... */
    fun ensureChannel(
        context: Context,
        id: String,
        @StringRes nameRes: Int,
        importance: Int,
        @StringRes descriptionRes: Int? = null,
        configure: NotificationChannel.() -> Unit = {}
    ) {
        val channel = NotificationChannel(id, context.getString(nameRes), importance).apply {
            if (descriptionRes != null) description = context.getString(descriptionRes)
            configure()
        }
        context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    /** A [PendingIntent] that starts [intent] as a new task. */
    fun activityIntent(context: Context, requestCode: Int, intent: Intent): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode,
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    /** A [PendingIntent] that opens the app's main screen. */
    fun openAppIntent(context: Context, requestCode: Int): PendingIntent =
        activityIntent(context, requestCode, Intent(context, MainActivity::class.java))
}
