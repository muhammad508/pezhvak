package ir.fastflutter.pezhvak

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Receives scheduled alarms: repeat alarms, test alarms, and the daily summary. */
class AlarmActionReceiver : BroadcastReceiver() {

    private companion object {
        const val TAG = "AlarmActionReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        try {
            when (intent?.action) {
                RepeatAlarm.ACTION -> RepeatAlarm.onFire(context)
                AlarmLauncher.ACTION_TEST -> AlarmLauncher.fireTest(context)
                DailySummary.ACTION -> DailySummary.onFire(context)
            }
        } catch (e: Exception) {
            Log.e(TAG, "${intent?.action} failed: $e")
            DiagnosticsLog.record(
                "error",
                context.getString(R.string.diag_error_scheduled_action, intent?.action ?: ""),
                e.toString()
            )
        }
    }
}
