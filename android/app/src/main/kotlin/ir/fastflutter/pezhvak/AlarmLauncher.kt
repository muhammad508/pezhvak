package ir.fastflutter.pezhvak

import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.AtomicFile
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Shared launcher for the alarm screen, used by the listener, repeat alarms and test alarms.
 *
 * The file [StorageFiles.PENDING_ALARM] means "an alarm is still pending"; Flutter deletes it when
 * the user dismisses the alarm.
 */
object AlarmLauncher {
    private const val TAG = "AlarmLauncher"
    const val ACTION_TEST = "ir.fastflutter.pezhvak.TEST_ALARM"
    private const val TEST_REQUEST_CODE = 12
    private const val WAKE_LOCK_TAG = "pezhvak:alarm"
    private const val WAKE_LOCK_TIMEOUT_MS = 30_000L

    private var wakeLock: PowerManager.WakeLock? = null

    /**
     * Shows the alarm. The payload holds `package_name`, `app_name`, `title`, `text` and,
     * optionally, `priority`, `sound_path`, `vibration`, `rule_kind`, `rule_text` and `is_test`.
     * With a positive [repeatMinutes] the alarm comes back until the user dismisses it.
     */
    @Synchronized
    fun fire(context: Context, payload: JSONObject, repeatMinutes: Int = 0) {
        val ctx = context.applicationContext
        writePayload(ctx, payload)
        RepeatAlarm.cancel(ctx)
        if (repeatMinutes > 0) RepeatAlarm.schedule(ctx, repeatMinutes, 0)
        launch(ctx)
    }

    /** Brings the still-pending alarm screen back up. Returns false when no alarm is pending anymore. */
    @Synchronized
    fun relaunchPending(context: Context): Boolean {
        val ctx = context.applicationContext
        if (!File(ctx.filesDir, StorageFiles.PENDING_ALARM).exists()) return false
        launch(ctx)
        return true
    }

    fun scheduleTest(context: Context, delaySeconds: Int) {
        val ctx = context.applicationContext
        if (delaySeconds <= 0) {
            fireTest(ctx)
            return
        }
        val pi = AlarmScheduling.broadcast(ctx, AlarmActionReceiver::class.java, ACTION_TEST, TEST_REQUEST_CODE)
        AlarmScheduling.setWake(ctx, System.currentTimeMillis() + delaySeconds * 1000L, pi)
    }

    fun fireTest(context: Context) {
        val payload = JSONObject().apply {
            put("package_name", context.packageName)
            put("app_name", context.getString(R.string.app_display_name))
            put("title", context.getString(R.string.test_alarm_title))
            put("text", context.getString(R.string.test_alarm_text))
            put("priority", PRIORITY_NORMAL)
            put("is_test", true)
        }
        fire(context, payload, 0)
    }

    private fun launch(ctx: Context) {
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = wakeLock ?: pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG).also {
            it.setReferenceCounted(false)
            wakeLock = it
        }
        lock.acquire(WAKE_LOCK_TIMEOUT_MS)

        val intent = Intent(ctx, UnlockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        try {
            ctx.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "startActivity failed: $e")
            DiagnosticsLog.record("error", ctx.getString(R.string.diag_error_open_alarm), e.toString())
        }
    }

    // Atomic write: Flutter reads this file and must never see a half-written one.
    private fun writePayload(ctx: Context, payload: JSONObject) {
        try {
            val atomic = AtomicFile(File(ctx.filesDir, StorageFiles.PENDING_ALARM))
            val out = atomic.startWrite()
            try {
                out.write(payload.toString().toByteArray(Charsets.UTF_8))
                atomic.finishWrite(out)
            } catch (e: Exception) {
                atomic.failWrite(out)
                throw e
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write ${StorageFiles.PENDING_ALARM}: $e")
        }
    }
}
