package ir.fastflutter.pezhvak

import android.content.Context
import java.time.LocalDate

/** Daily counters: how many notifications were checked and how many alarms fired. */
object DailyStats {
    private const val KEY_DAY = "stats_day"
    private const val KEY_NOTIFICATIONS = "stats_notifs"
    private const val KEY_ALARMS = "stats_alarms"

    @Synchronized
    fun record(context: Context, alarm: Boolean) {
        val prefs = AppPrefs.of(context)
        val today = LocalDate.now().toString()
        var notifications = prefs.getInt(KEY_NOTIFICATIONS, 0)
        var alarms = prefs.getInt(KEY_ALARMS, 0)
        if (prefs.getString(KEY_DAY, "") != today) {
            notifications = 0
            alarms = 0
        }
        prefs.edit()
            .putString(KEY_DAY, today)
            .putInt(KEY_NOTIFICATIONS, notifications + 1)
            .putInt(KEY_ALARMS, if (alarm) alarms + 1 else alarms)
            .apply()
    }

    /** Returns (notifications, alarms) for today. */
    @Synchronized
    fun today(context: Context): Pair<Int, Int> {
        val prefs = AppPrefs.of(context)
        if (prefs.getString(KEY_DAY, "") != LocalDate.now().toString()) return 0 to 0
        return prefs.getInt(KEY_NOTIFICATIONS, 0) to prefs.getInt(KEY_ALARMS, 0)
    }
}
