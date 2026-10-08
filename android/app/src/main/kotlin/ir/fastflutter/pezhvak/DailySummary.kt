package ir.fastflutter.pezhvak

import android.app.NotificationManager
import android.content.Context
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

/** The "daily summary" notification, posted at a user-chosen time (22:00 by default). */
object DailySummary {
    private const val TAG = "DailySummary"
    const val ACTION = "ir.fastflutter.pezhvak.DAILY_SUMMARY"
    private const val REQUEST_CODE = 13
    private const val NOTIFICATION_ID = 2002
    private const val CHANNEL_ID = "DailySummaryChannel"

    private const val KEY_ENABLED = "summary_enabled"
    private const val KEY_HOUR = "summary_hour"
    private const val KEY_MINUTE = "summary_minute"
    private const val DEFAULT_HOUR = 22

    /** A process younger than this has not had time to bind the listener yet. */
    private const val FRESH_PROCESS_MS = 2 * 60_000L

    /** Alarms due within this window are treated as already past (avoids re-firing immediately). */
    private const val SCHEDULING_MARGIN_MS = 1_000L

    fun isEnabled(context: Context) = AppPrefs.of(context).getBoolean(KEY_ENABLED, true)

    fun hour(context: Context) = AppPrefs.of(context).getInt(KEY_HOUR, DEFAULT_HOUR)

    fun minute(context: Context) = AppPrefs.of(context).getInt(KEY_MINUTE, 0)

    fun configure(context: Context, enabled: Boolean, hour: Int, minute: Int) {
        AppPrefs.of(context).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putInt(KEY_HOUR, hour.coerceIn(0, 23))
            .putInt(KEY_MINUTE, minute.coerceIn(0, 59))
            .apply()
        ensureScheduled(context)
    }

    /** Safe to call repeatedly; it always (re)schedules the next occurrence. */
    fun ensureScheduled(context: Context) {
        val ctx = context.applicationContext
        val pi = AlarmScheduling.broadcast(ctx, AlarmActionReceiver::class.java, ACTION, REQUEST_CODE)
        if (!isEnabled(ctx)) {
            AlarmScheduling.cancel(ctx, pi)
            return
        }
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour(ctx))
            set(Calendar.MINUTE, minute(ctx))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis() + SCHEDULING_MARGIN_MS) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        // The summary does not need minute precision, and an inexact alarm needs no special permission.
        AlarmScheduling.setWake(ctx, next.timeInMillis, pi, exact = false)
    }

    fun onFire(context: Context) {
        try {
            post(context)
        } catch (e: Exception) {
            Log.e(TAG, "post failed: $e")
        }
        ensureScheduled(context)
    }

    private fun post(context: Context) {
        if (!AppPrefs.isServiceEnabled(context)) return
        val nm = NotificationManagerCompat.from(context)
        if (!nm.areNotificationsEnabled()) return

        val (notifications, alarms) = DailyStats.today(context)
        val message = StringBuilder(context.getString(R.string.summary_text, notifications, alarms))
        val processIsFresh = System.currentTimeMillis() - PezhvakApp.processStartMs < FRESH_PROCESS_MS
        if (!processIsFresh && !MyNotificationListenerService.isConnected) {
            message.append("\n").append(context.getString(R.string.summary_listener_down))
        }

        NotificationSupport.ensureChannel(
            context, CHANNEL_ID, R.string.summary_channel_name,
            NotificationManager.IMPORTANCE_DEFAULT, R.string.summary_channel_description
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_pezhvak)
            .setContentTitle(context.getString(R.string.summary_title))
            .setContentText(message.lineSequence().first())
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setAutoCancel(true)
            .setContentIntent(NotificationSupport.openAppIntent(context, NOTIFICATION_ID))
            .build()
        @Suppress("MissingPermission") // Guarded by areNotificationsEnabled() above.
        nm.notify(NOTIFICATION_ID, notification)
    }
}
