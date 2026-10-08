package ir.fastflutter.pezhvak

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/** Shared alarm scheduling helpers (exact when permitted, inexact otherwise). */
object AlarmScheduling {
    private const val TAG = "AlarmScheduling"

    /** A broadcast [PendingIntent] for [cls] carrying [action]; the same arguments always match. */
    fun broadcast(context: Context, cls: Class<*>, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, cls).apply { this.action = action }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Schedules a wake-up alarm. From Android 12 the exact-alarm permission may be denied,
     * in which case an inexact alarm is used instead.
     */
    fun setWake(context: Context, triggerAt: Long, pi: PendingIntent, exact: Boolean = true) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            val canExact = exact &&
                (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms())
            if (canExact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Exact alarm denied, using inexact: $e")
            try {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } catch (e2: Exception) {
                Log.e(TAG, "Failed to schedule alarm: $e2")
            }
        }
    }

    fun cancel(context: Context, pi: PendingIntent) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
    }
}
