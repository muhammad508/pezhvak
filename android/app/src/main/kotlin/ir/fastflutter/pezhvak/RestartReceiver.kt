package ir.fastflutter.pezhvak

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles boot completion, package replacement and the 15-minute watchdog tick: restarts the
 * foreground service, runs [ServiceWatchdog] and reschedules itself.
 */
class RestartReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "Received: ${intent?.action}")

        // The daily summary is independent of the watchdog; it is rescheduled after boot and on every tick.
        DailySummary.ensureScheduled(context)

        if (!AppPrefs.isServiceEnabled(context)) return

        try {
            context.startForegroundService(Intent(context, MonitoringForegroundService::class.java))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart service: $e")
        }

        try {
            ServiceWatchdog.check(context)
        } catch (e: Exception) {
            Log.e(TAG, "Watchdog failed: $e")
        }

        scheduleRestart(context)
    }

    companion object {
        private const val TAG = "RestartReceiver"
        private const val ACTION = "ir.fastflutter.pezhvak.RESTART_SERVICE"

        // Instant listener reconnects are handled by onListenerDisconnected and START_STICKY;
        // this tick only needs to catch what those miss.
        private const val RESTART_INTERVAL_MS = 15 * 60_000L

        private fun pendingIntent(context: Context): PendingIntent =
            AlarmScheduling.broadcast(context, RestartReceiver::class.java, ACTION, 0)

        fun scheduleRestart(context: Context) {
            AlarmScheduling.setWake(
                context, System.currentTimeMillis() + RESTART_INTERVAL_MS, pendingIntent(context)
            )
        }

        fun cancelRestart(context: Context) {
            AlarmScheduling.cancel(context, pendingIntent(context))
        }
    }
}
