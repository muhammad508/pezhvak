package ir.fastflutter.pezhvak

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Health watchdog for notification monitoring. Runs on every RestartReceiver tick:
 *  - If notification access was revoked, it tells the user.
 *  - If the listener is not connected, it requests a rebind and warns the user once the outage
 *    lasts longer than [DOWN_ALERT_AFTER_MS].
 */
object ServiceWatchdog {
    private const val TAG = "ServiceWatchdog"
    private const val CHANNEL_ID = "ServiceAlertChannel"
    private const val ALERT_ID = 2001
    private const val DOWN_ALERT_AFTER_MS = 10 * 60_000L
    private const val MINUTE_MS = 60_000L

    /** Written by the listener whenever it connects or disconnects. */
    const val KEY_STATE_TS = "listener_state_ts"

    fun hasNotificationAccess(context: Context): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)

    fun check(context: Context) {
        if (!AppPrefs.isServiceEnabled(context)) {
            clearAlert(context)
            return
        }

        if (!hasNotificationAccess(context)) {
            postAlert(
                context,
                context.getString(R.string.alert_access_revoked_title),
                context.getString(R.string.alert_access_revoked_text),
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            )
            return
        }

        if (MyNotificationListenerService.isConnected) {
            clearAlert(context)
            return
        }

        requestRebind(context)

        // Start of the outage: the last listener state change or this process's start, whichever
        // is later. A fresh process gives the system time to bind the listener again.
        val since = maxOf(AppPrefs.of(context).getLong(KEY_STATE_TS, 0L), PezhvakApp.processStartMs)
        val downFor = System.currentTimeMillis() - since
        if (downFor >= DOWN_ALERT_AFTER_MS) {
            DiagnosticsLog.record(
                "watchdog",
                context.getString(R.string.diag_watchdog_down, downFor / MINUTE_MS),
                context.getString(R.string.diag_watchdog_detail)
            )
            forceRebind(context)
            postAlert(
                context,
                context.getString(R.string.alert_stopped_title),
                context.getString(R.string.alert_stopped_text),
                Intent(context, MainActivity::class.java)
            )
        }
    }

    fun requestRebind(context: Context) {
        try {
            NotificationListenerService.requestRebind(
                ComponentName(context, MyNotificationListenerService::class.java)
            )
        } catch (e: Exception) {
            Log.e(TAG, "requestRebind failed: $e")
        }
    }

    /** Well-known trick: disabling and re-enabling the component forces the system to bind it again. */
    fun forceRebind(context: Context) {
        try {
            val pm = context.packageManager
            val component = ComponentName(context, MyNotificationListenerService::class.java)
            pm.setComponentEnabledSetting(
                component, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                component, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP
            )
            requestRebind(context)
        } catch (e: Exception) {
            Log.e(TAG, "forceRebind failed: $e")
        }
    }

    fun clearAlert(context: Context) {
        try {
            NotificationManagerCompat.from(context).cancel(ALERT_ID)
        } catch (e: Exception) {
            Log.e(TAG, "clearAlert failed: $e")
        }
    }

    private fun postAlert(context: Context, title: String, text: String, target: Intent) {
        try {
            val nm = NotificationManagerCompat.from(context)
            if (!nm.areNotificationsEnabled()) return

            NotificationSupport.ensureChannel(
                context, CHANNEL_ID, R.string.alert_channel_name,
                NotificationManager.IMPORTANCE_HIGH, R.string.alert_channel_description
            )
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_pezhvak)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ERROR)
                .setAutoCancel(true)
                .setContentIntent(NotificationSupport.activityIntent(context, ALERT_ID, target))
                .build()
            @Suppress("MissingPermission") // Guarded by areNotificationsEnabled() above.
            nm.notify(ALERT_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "postAlert failed: $e")
        }
    }
}
