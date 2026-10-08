package ir.fastflutter.pezhvak

import android.content.Context

/**
 * "Repeat until acknowledged": while the user has not dismissed the alarm
 * ([StorageFiles.PENDING_ALARM] still exists), the alarm screen comes back every few minutes,
 * at most [MAX_REPEATS] times.
 */
object RepeatAlarm {
    const val ACTION = "ir.fastflutter.pezhvak.REPEAT_ALARM"
    private const val REQUEST_CODE = 11
    const val MAX_REPEATS = 10
    private const val DEFAULT_MINUTES = 2

    private const val KEY_COUNT = "repeat_count"
    private const val KEY_MINUTES = "repeat_minutes"

    fun schedule(context: Context, minutes: Int, count: Int) {
        AppPrefs.of(context).edit()
            .putInt(KEY_COUNT, count)
            .putInt(KEY_MINUTES, minutes)
            .apply()
        val pi = AlarmScheduling.broadcast(context, AlarmActionReceiver::class.java, ACTION, REQUEST_CODE)
        AlarmScheduling.setWake(context, System.currentTimeMillis() + minutes * 60_000L, pi)
    }

    fun cancel(context: Context) {
        val pi = AlarmScheduling.broadcast(context, AlarmActionReceiver::class.java, ACTION, REQUEST_CODE)
        AlarmScheduling.cancel(context, pi)
    }

    fun onFire(context: Context) {
        val prefs = AppPrefs.of(context)
        val count = prefs.getInt(KEY_COUNT, 0) + 1
        val minutes = prefs.getInt(KEY_MINUTES, DEFAULT_MINUTES)
        if (count > MAX_REPEATS) return
        // The alarm was dismissed (or does not exist), so the repeating is over.
        if (!AlarmLauncher.relaunchPending(context)) return
        schedule(context, minutes, count)
    }
}
