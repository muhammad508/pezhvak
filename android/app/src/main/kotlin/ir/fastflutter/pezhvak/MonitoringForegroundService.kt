package ir.fastflutter.pezhvak

import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service whose only job is to keep the process (and therefore the notification
 * listener) alive. Uses the `specialUse` type on Android 14+, which has no runtime cap, unlike
 * `dataSync`.
 */
class MonitoringForegroundService : Service() {

    private companion object {
        const val CHANNEL_ID = "ForegroundServiceChannel"
        const val NOTIFICATION_ID = 1
    }

    override fun onCreate() {
        super.onCreate()
        NotificationSupport.ensureChannel(
            this, CHANNEL_ID, R.string.fg_channel_name, NotificationManager.IMPORTANCE_LOW
        )
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // The system binds the listener (startService has no effect on it), so the only thing
        // to do is to ask for a rebind when it is not connected.
        if (!MyNotificationListenerService.isConnected && ServiceWatchdog.hasNotificationAccess(this)) {
            ServiceWatchdog.requestRebind(this)
        }
        RestartReceiver.scheduleRestart(this)
        return START_STICKY
    }

    private fun createNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_pezhvak)
            .setContentTitle(getString(R.string.fg_title))
            .setContentText(getString(R.string.fg_text))
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(NotificationSupport.openAppIntent(this, 0))
            .setOngoing(true) // Keeps the notification from being swiped away.
            .build()

    // Android 15+: if the system signals a foreground-service timeout and the service does not
    // stop, the whole app is killed. Stop cleanly instead and let the watchdog restart it later.
    override fun onTimeout(startId: Int, fgsType: Int) {
        DiagnosticsLog.record("fgs_timeout", getString(R.string.diag_fgs_timeout), "startId=$startId type=$fgsType")
        stopSelf()
    }

    override fun onTimeout(startId: Int) {
        DiagnosticsLog.record("fgs_timeout", getString(R.string.diag_fgs_timeout), "startId=$startId")
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        RestartReceiver.scheduleRestart(this)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        if (AppPrefs.isServiceEnabled(this)) {
            RestartReceiver.scheduleRestart(this)
        }
        super.onDestroy()
    }
}
