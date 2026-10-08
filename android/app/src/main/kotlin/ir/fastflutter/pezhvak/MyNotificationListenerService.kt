package ir.fastflutter.pezhvak

import android.app.Notification
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Receives every notification, matches it against the user's rules and raises an alarm.
 *
 * The component name is part of the notification-access grant that users already gave, so
 * it must not be renamed. All heavy work runs on a single worker thread.
 */
class MyNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotificationListener"

        // Cap of the stored history; the free/premium display limit is applied on the Flutter side.
        private const val HISTORY_MAX = 10_000

        /** The same app cannot raise a normal alarm again within this time. */
        private const val COOLDOWN_MS = 60_000L

        /** How long an app stays muted after the user dismissed one of its alarms. */
        private const val SUPPRESSION_MS = 5 * 60_000L

        /** Upper bound of remembered notifications used to detect unchanged re-posts. */
        private const val SEEN_CACHE_MAX = 500

        private const val ERROR_DETAIL_LIMIT = 2000

        // Listener connection state; read by the watchdog (ServiceWatchdog) and the foreground service.
        @Volatile
        var isConnected = false
            private set
    }

    // All heavy work (files, filtering, history) runs on this thread, never on the main thread.
    // It is a single thread, so the maps below are safe without locking.
    private val executor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "pezhvak-notif-worker").apply { isDaemon = true }
    }

    // Time of the last normal alarm per app, for the cooldown.
    private val appLastTriggerTime = mutableMapOf<String, Long>()

    // Last content seen for each notification (keyed by sbn.key). Used to detect unchanged
    // re-posts (e.g. Telegram re-posts older unread notifications when a new message arrives)
    // so they do not repeat in alarms and history.
    private data class SeenNotification(val whenTs: Long, val signature: String)
    private val lastSeenByKey = mutableMapOf<String, SeenNotification>()

    private lateinit var keywordsCache: JsonFileCache<List<String>>
    private lateinit var titlesCache: JsonFileCache<List<String>>
    private lateinit var selectedAppsCache: JsonFileCache<Set<String>>
    private lateinit var scheduleCache: JsonFileCache<JSONObject?>
    private lateinit var suppressedCache: JsonFileCache<JSONObject>
    private lateinit var ruleOptionsCache: JsonFileCache<Map<String, RuleOptions>>

    private lateinit var notificationHistory: HistoryStore
    private lateinit var alarmHistory: HistoryStore

    override fun onCreate() {
        super.onCreate()

        val dir = applicationContext.filesDir
        keywordsCache = JsonFileCache({ File(dir, StorageFiles.KEYWORDS) }, emptyList(), ::parseStringList)
        titlesCache = JsonFileCache({ File(dir, StorageFiles.TITLES) }, emptyList(), ::parseStringList)
        selectedAppsCache =
            JsonFileCache({ File(dir, StorageFiles.SELECTED_APPS) }, emptySet()) { parseStringList(it).toSet() }
        scheduleCache = JsonFileCache({ File(dir, StorageFiles.SCHEDULE) }, null) { JSONObject(it) }
        suppressedCache =
            JsonFileCache({ File(dir, StorageFiles.SUPPRESSED_APPS) }, JSONObject()) { JSONObject(it) }
        ruleOptionsCache = JsonFileCache({ File(dir, StorageFiles.RULE_OPTIONS) }, emptyMap(), ::parseRuleOptions)

        notificationHistory = HistoryStore(dir, StorageFiles.NOTIFICATION_HISTORY, HISTORY_MAX)
        alarmHistory = HistoryStore(dir, StorageFiles.ALARM_HISTORY, HISTORY_MAX)
    }

    override fun onDestroy() {
        isConnected = false
        executor.shutdown()
        super.onDestroy()
    }

    // The system connects this service after boot, an update, or an automatic reconnect.
    // Use the moment to make sure the foreground service is running and the restart alarm is scheduled.
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Listener connected")
        isConnected = true
        AppPrefs.of(this).edit().putLong(ServiceWatchdog.KEY_STATE_TS, System.currentTimeMillis()).apply()
        ServiceWatchdog.clearAlert(applicationContext)
        ensureForegroundServiceRunning()
        RestartReceiver.scheduleRestart(applicationContext)
        DailySummary.ensureScheduled(applicationContext)
    }

    // If the system disconnects this service (process killed, low resources, ...),
    // immediately try to reconnect and schedule a service restart.
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "Listener disconnected; attempting recovery")
        isConnected = false
        AppPrefs.of(this).edit().putLong(ServiceWatchdog.KEY_STATE_TS, System.currentTimeMillis()).apply()
        DiagnosticsLog.record(
            "listener",
            getString(R.string.diag_listener_disconnected),
            getString(R.string.diag_listener_disconnected_detail)
        )
        RestartReceiver.scheduleRestart(applicationContext)
        ServiceWatchdog.requestRebind(applicationContext)
        ensureForegroundServiceRunning()
    }

    private fun ensureForegroundServiceRunning() {
        if (!AppPrefs.isServiceEnabled(this)) return
        try {
            applicationContext.startForegroundService(
                Intent(applicationContext, MonitoringForegroundService::class.java)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start the foreground service: $e")
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        // Skip everything when the user has turned the service off.
        if (!AppPrefs.isServiceEnabled(this)) return

        // Ignore group-summary notifications (such as "3 new messages" in Telegram/WhatsApp).
        // They merely wrap individual notifications, which are processed separately,
        // and the summary is re-posted every time a new message arrives.
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        // Extract only the needed data from sbn here; the rest happens on the worker thread.
        val packageName = sbn.packageName
        val extras = sbn.notification.extras
        val title = (extras.getCharSequence(Notification.EXTRA_TITLE) ?: "").toString()
        val text = run {
            val bigText = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: "").toString()
            if (bigText.isNotBlank()) return@run bigText
            val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            if (!lines.isNullOrEmpty()) return@run lines.joinToString("\n")
            (extras.getCharSequence(Notification.EXTRA_TEXT) ?: "").toString()
        }
        if (text.isBlank()) return

        val key = sbn.key ?: "$packageName-${sbn.id}-${sbn.tag}"
        val whenTs = sbn.notification.`when`

        submit {
            processNotification(packageName, key, whenTs, title, text)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val key = sbn.key ?: "${sbn.packageName}-${sbn.id}-${sbn.tag}"
        submit { lastSeenByKey.remove(key) }
    }

    private fun submit(task: () -> Unit) {
        try {
            executor.execute {
                try {
                    task()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to process notification: $e")
                    DiagnosticsLog.record(
                        "error",
                        getString(R.string.diag_error_processing),
                        Log.getStackTraceString(e).take(ERROR_DETAIL_LIMIT)
                    )
                }
            }
        } catch (_: RejectedExecutionException) {
            // The service is being destroyed.
        }
    }

    // Only called on the worker thread.
    private fun processNotification(packageName: String, key: String, whenTs: Long, title: String, text: String) {
        val currentTime = System.currentTimeMillis()

        if (isUnchangedRepost(key, whenTs, "$title $text")) return

        val appName = getAppName(packageName)

        // Matching rules in priority order; the first one that passes schedule and cooldown checks wins.
        val matches = findMatches(packageName, appName, title, text)
        val chosen = if (matches.isEmpty()) null else chooseRule(matches, packageName, currentTime)

        val isSilent = chosen != null && chosen.options.priority == PRIORITY_SILENT
        val isAlarm = chosen != null && !isSilent

        DailyStats.record(applicationContext, isAlarm)

        // Save to the full notification history; the alarm state and matched rule are already known here.
        notificationHistory.append(historyEntry(packageName, appName, title, text, currentTime, chosen).apply {
            put("triggered_alarm", isAlarm)
        })

        if (chosen == null) return

        if (isSilent) {
            SilentMatchNotifier.post(applicationContext, appName, title, text)
            return
        }

        appLastTriggerTime[packageName] = currentTime
        alarmHistory.append(historyEntry(packageName, appName, title, text, currentTime, chosen))

        val options = chosen.options
        val payload = JSONObject().apply {
            put("package_name", packageName)
            put("app_name", appName)
            put("title", title)
            put("text", text)
            put("priority", options.priority)
            put("sound_path", options.sound)
            put("vibration", options.vibration)
            put("rule_kind", chosen.kind)
            put("rule_text", chosen.text)
        }
        AlarmLauncher.fire(applicationContext, payload, if (options.repeat) options.repeatMinutes else 0)
    }

    /**
     * Detects an unchanged rebuild/re-post and remembers the notification otherwise.
     *
     * sbn.key (package + tag + id + user) is stable for a given notification, and
     * notification.when is the time the posting app assigned to the content: unlike the delivery
     * time, it does not change when the same content is re-posted.
     */
    private fun isUnchangedRepost(key: String, whenTs: Long, signature: String): Boolean {
        val previous = lastSeenByKey[key]
        if (previous != null && previous.whenTs == whenTs && previous.signature == signature) return true

        lastSeenByKey[key] = SeenNotification(whenTs, signature)
        if (lastSeenByKey.size > SEEN_CACHE_MAX) {
            // Bound the map's growth by dropping old entries (exact order does not matter, only the size).
            val excess = lastSeenByKey.size - SEEN_CACHE_MAX
            lastSeenByKey.keys.take(excess).forEach { lastSeenByKey.remove(it) }
        }
        return false
    }

    private fun historyEntry(
        packageName: String, appName: String, title: String, text: String, timestamp: Long, rule: MatchedRule?
    ) = JSONObject().apply {
        put("package_name", packageName)
        put("app_name", appName)
        put("title", title)
        put("text", text)
        put("timestamp", timestamp)
        if (rule != null) {
            put("matched_kind", rule.kind)
            put("matched_text", rule.text)
            put("priority", rule.options.priority)
        }
    }

    /**
     * All rules that match this notification (keyword, title, selected app).
     * Advanced options (negative words, priority, ...) apply to premium users only.
     */
    private fun findMatches(packageName: String, appName: String, title: String, text: String): List<MatchedRule> {
        val optionsMap = if (PremiumStatus.isPremium(applicationContext)) ruleOptionsCache.get() else emptyMap()
        val out = mutableListOf<MatchedRule>()

        for (keyword in keywordsCache.get()) {
            if (keyword.isBlank() || !text.contains(keyword, ignoreCase = true)) continue
            val options = optionsMap["k:$keyword"] ?: RuleOptions()
            if (!isExcluded(options, title, text)) out.add(MatchedRule("keyword", keyword, options))
        }
        for (titleRule in titlesCache.get()) {
            if (titleRule.isBlank() || !title.contains(titleRule, ignoreCase = true)) continue
            val options = optionsMap["t:$titleRule"] ?: RuleOptions()
            if (!isExcluded(options, title, text)) out.add(MatchedRule("title", titleRule, options))
        }
        if (selectedAppsCache.get().contains(packageName)) {
            out.add(MatchedRule("app", appName, RuleOptions()))
        }
        return out.sortedBy { it.rank }
    }

    // Negative words: if any appears in the title or text, this rule (and only this rule) does not fire.
    private fun isExcluded(options: RuleOptions, title: String, text: String): Boolean =
        options.excludes.any {
            it.isNotBlank() && (text.contains(it, ignoreCase = true) || title.contains(it, ignoreCase = true))
        }

    private fun chooseRule(matches: List<MatchedRule>, packageName: String, now: Long): MatchedRule? {
        val globalOk = withinSchedule(scheduleCache.get())
        for (match in matches) {
            val options = match.options
            // Global schedule (unless the rule opted out via "ignore global schedule"), then the rule's own.
            if (!options.ignoreGlobalSchedule && !globalOk) continue
            if (!withinSchedule(options.schedule)) continue
            // Cooldown and suppression apply to normal alarms only: urgent rules always fire and
            // silent rules never raise an alarm.
            val throttled = isInCooldown(packageName, now) || isAppSuppressed(packageName, now)
            if (options.priority == PRIORITY_NORMAL && throttled) continue
            return match
        }
        return null
    }

    private fun isInCooldown(packageName: String, currentTime: Long): Boolean {
        val lastTrigger = appLastTriggerTime[packageName] ?: 0L
        return currentTime - lastTrigger < COOLDOWN_MS
    }

    // Suppressed apps: muted for SUPPRESSION_MS after an alarm was dismissed.
    private fun isAppSuppressed(packageName: String, currentTime: Long): Boolean {
        return try {
            val suppressed = suppressedCache.get()
            suppressed.has(packageName) && currentTime - suppressed.getLong(packageName) < SUPPRESSION_MS
        } catch (_: Exception) {
            false
        }
    }

    /** A null json or enabled=false means there is no restriction. */
    private fun withinSchedule(json: JSONObject?): Boolean {
        return try {
            if (json == null || !json.optBoolean("enabled", false)) return true

            val now = Calendar.getInstance()
            val currentDayOfWeek = now.get(Calendar.DAY_OF_WEEK) // 1 = Sunday ... 7 = Saturday

            val days = json.optJSONArray("days")
            if (days != null && days.length() > 0) {
                val dayMatches = (0 until days.length()).any { days.getInt(it) == currentDayOfWeek }
                if (!dayMatches) return false
            }

            val currentTotal = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val startTotal = json.optInt("start_hour", 0) * 60 + json.optInt("start_minute", 0)
            val endTotal = json.optInt("end_hour", 23) * 60 + json.optInt("end_minute", 59)

            if (startTotal <= endTotal) {
                currentTotal in startTotal..endTotal
            } else {
                // The window crosses midnight.
                currentTotal >= startTotal || currentTotal <= endTotal
            }
        } catch (_: Exception) {
            true
        }
    }

    private fun getAppName(packageName: String): String {
        return try {
            val pm = applicationContext.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (_: Exception) {
            packageName
        }
    }

    private fun parseStringList(content: String): List<String> {
        val array = JSONArray(content)
        return (0 until array.length()).map { array.getString(it) }
    }
}
