package ir.fastflutter.pezhvak

import android.content.Context
import android.content.SharedPreferences

/** The native side's SharedPreferences file and the flags several components share. */
internal object AppPrefs {
    /** The file name is persisted on user devices, so it must not be renamed. */
    private const val NAME = "MyAppPrefs"

    /** Whether the user switched monitoring on; mirrored from Flutter by the service channel. */
    private const val KEY_SERVICE_ENABLED = "service_enabled"

    fun of(context: Context): SharedPreferences =
        context.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    fun isServiceEnabled(context: Context): Boolean =
        of(context).getBoolean(KEY_SERVICE_ENABLED, true)

    fun setServiceEnabled(context: Context, enabled: Boolean) {
        of(context).edit().putBoolean(KEY_SERVICE_ENABLED, enabled).apply()
    }
}

/**
 * Names of the JSON files in the app's files directory. Flutter and the native side share them,
 * so a rename has to happen on both sides (see `StorageFiles` in the Dart code).
 */
internal object StorageFiles {
    const val KEYWORDS = "keywords.json"
    const val TITLES = "titles.json"
    const val SELECTED_APPS = "selected_apps.json"
    const val SCHEDULE = "schedule.json"
    const val SUPPRESSED_APPS = "suppressed_apps.json"
    const val RULE_OPTIONS = "rules.json"
    const val PREMIUM = "premium.json"

    /** Exists while an alarm is on screen or waiting for the user to dismiss it. */
    const val PENDING_ALARM = "notification.json"

    /** History base names; the stores add `.jsonl` (and read a legacy `.json` array once). */
    const val NOTIFICATION_HISTORY = "notification_history"
    const val ALARM_HISTORY = "alarm_history"
}
