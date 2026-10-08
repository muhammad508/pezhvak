package ir.fastflutter.pezhvak

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Stability diagnostics log: process exit reasons (ApplicationExitInfo), crashes and service events.
 * Stored as JSONL (one event per line); only the latest [MAX_ENTRIES] events are kept.
 */
object DiagnosticsLog {
    private const val TAG = "DiagnosticsLog"
    private const val FILE_NAME = "diagnostics_log.jsonl"
    private const val MAX_ENTRIES = 200
    private const val TRIM_SLACK = 50
    private const val KEY_LAST_EXIT_TS = "diag_last_exit_ts"
    private const val STACK_TRACE_LIMIT = 4000
    private const val EXIT_REASONS_TO_READ = 10

    private lateinit var appContext: Context

    private val log by lazy {
        JsonlFile(File(appContext.filesDir, FILE_NAME), MAX_ENTRIES, TRIM_SLACK)
    }

    fun install(app: Context) {
        appContext = app.applicationContext

        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                record(
                    "crash",
                    app.getString(R.string.diag_crash_title, thread.name),
                    Log.getStackTraceString(throwable).take(STACK_TRACE_LIMIT)
                )
            } catch (_: Throwable) {
                // Never let the diagnostics hide the original crash.
            }
            previous?.uncaughtException(thread, throwable)
        }

        // Reading earlier exit reasons is an IPC call, so keep it off the main thread.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Thread { recordExitReasons() }.apply { name = "diag-exit-reasons"; start() }
        }
    }

    fun record(type: String, title: String, detail: String = "", extra: JSONObject? = null) =
        append(System.currentTimeMillis(), type, title, detail, extra)

    /** Returns the events as a JSON array, newest first. */
    fun readAll(): String {
        val events = JSONArray()
        try {
            log.readLines().asReversed().forEach { line ->
                try {
                    events.put(JSONObject(line))
                } catch (_: Exception) {
                    // Skip a partial line left by an interrupted write.
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "readAll failed: $e")
        }
        return events.toString()
    }

    fun clear() {
        try {
            log.clear()
        } catch (e: Exception) {
            Log.e(TAG, "clear failed: $e")
        }
    }

    private fun recordExitReasons() {
        try {
            val am = appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val prefs = AppPrefs.of(appContext)
            val lastTs = prefs.getLong(KEY_LAST_EXIT_TS, 0L)
            val exits = am.getHistoricalProcessExitReasons(appContext.packageName, 0, EXIT_REASONS_TO_READ)
                .filter { it.timestamp > lastTs }
                .sortedBy { it.timestamp }
            if (exits.isEmpty()) return

            for (info in exits) {
                val extra = JSONObject().apply {
                    put("reasonCode", info.reason)
                    put("reasonName", reasonName(info.reason))
                    put("importance", info.importance)
                    put("pssKb", info.pss)
                    put("rssKb", info.rss)
                    put("status", info.status)
                    put("process", info.processName)
                }
                append(
                    info.timestamp,
                    "exit",
                    appContext.getString(R.string.diag_exit_title, reasonName(info.reason)),
                    info.description ?: "",
                    extra
                )
            }
            prefs.edit().putLong(KEY_LAST_EXIT_TS, exits.maxOf { it.timestamp }).apply()
        } catch (e: Exception) {
            Log.e(TAG, "recordExitReasons failed: $e")
        }
    }

    private fun append(ts: Long, type: String, title: String, detail: String, extra: JSONObject?) {
        try {
            val entry = JSONObject().apply {
                put("ts", ts)
                put("type", type)
                put("title", title)
                put("detail", detail)
                if (extra != null) put("extra", extra)
            }
            log.append(entry.toString())
        } catch (e: Exception) {
            Log.e(TAG, "append failed: $e")
        }
    }

    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
        ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY"
        ApplicationExitInfo.REASON_CRASH -> "CRASH"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE"
        ApplicationExitInfo.REASON_ANR -> "ANR"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
        ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_OTHER -> "OTHER"
        else -> when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                reason == ApplicationExitInfo.REASON_FREEZER -> "FREEZER"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                reason == ApplicationExitInfo.REASON_PACKAGE_STATE_CHANGE -> "PACKAGE_STATE_CHANGE"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                reason == ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "PACKAGE_UPDATED"
            else -> "UNKNOWN_$reason"
        }
    }
}
