package ir.fastflutter.pezhvak

import android.app.AlarmManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.AtomicFile
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.File

class MainActivity : FlutterActivity() {

    private companion object {
        const val TAG = "MainActivity"

        // Method channels shared with the Dart side.
        const val SERVICE_CHANNEL = "ir.fastflutter.pezhvak/service"
        const val SYSTEM_CHANNEL = "ir.fastflutter.pezhvak/system"
        const val FILES_CHANNEL = "ir.fastflutter.pezhvak/files"

        // The files channel only touches these files, so a compromised or buggy
        // caller cannot read or overwrite anything else in the app's storage.
        val ALLOWED_JSON_FILES = setOf(StorageFiles.KEYWORDS, StorageFiles.TITLES)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyAlarmFlagsIfNeeded(intent)
        DailySummary.ensureScheduled(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyAlarmFlagsIfNeeded(intent)
    }

    private fun applyAlarmFlagsIfNeeded(intent: Intent?) {
        val isAlarm = intent?.getBooleanExtra("is_alarm", false) == true
        if (isAlarm) {
            // Alarm screen only: show over the lock screen and turn the display on.
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                keyguardManager.requestDismissKeyguard(this, null)
            }
        } else {
            // Normal launch: no lock-screen flags.
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(false)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    startMonitoringService()
                    result.success(null)
                }
                "stopForegroundService" -> {
                    stopMonitoringService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDiagnostics" -> result.success(DiagnosticsLog.readAll())
                "clearDiagnostics" -> {
                    DiagnosticsLog.clear()
                    result.success(null)
                }
                "getServiceStatus" -> result.success(getServiceStatus())
                "rebindListener" -> {
                    DiagnosticsLog.record("listener", getString(R.string.diag_listener_manual_rebind), "")
                    ServiceWatchdog.forceRebind(this)
                    result.success(null)
                }
                "getDeviceInfo" -> result.success(
                    mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "brand" to Build.BRAND,
                        "model" to Build.MODEL,
                        "sdk" to Build.VERSION.SDK_INT
                    )
                )
                "openAutoStartSettings" -> result.success(openAutoStartSettings())
                "testAlarm" -> {
                    AlarmLauncher.scheduleTest(this, call.argument<Int>("delaySeconds") ?: 0)
                    result.success(null)
                }
                "getDailySummary" -> result.success(
                    mapOf(
                        "enabled" to DailySummary.isEnabled(this),
                        "hour" to DailySummary.hour(this),
                        "minute" to DailySummary.minute(this)
                    )
                )
                "setDailySummary" -> {
                    DailySummary.configure(
                        this,
                        call.argument<Boolean>("enabled") ?: true,
                        call.argument<Int>("hour") ?: 22,
                        call.argument<Int>("minute") ?: 0
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Lets Dart write the keyword/title lists where the native listener reads them.
        MethodChannel(messenger, FILES_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "writeJsonList" -> writeJsonList(call, result)
                "readJsonList" -> readJsonList(call, result)
                else -> result.notImplemented()
            }
        }
    }

    /** Resolves the requested file name, rejecting anything outside [ALLOWED_JSON_FILES]. */
    private fun allowedFile(call: MethodCall, result: MethodChannel.Result): File? {
        val filename = call.argument<String>("filename")
        if (filename == null || filename !in ALLOWED_JSON_FILES) {
            result.error("INVALID_FILENAME", "File name is missing or not allowed", null)
            return null
        }
        return File(applicationContext.filesDir, filename)
    }

    private fun writeJsonList(call: MethodCall, result: MethodChannel.Result) {
        val file = allowedFile(call, result) ?: return
        val list = call.argument<List<String>>("list") ?: emptyList()
        try {
            // Atomic write: the listener must never read a half-written file.
            val atomic = AtomicFile(file)
            val out = atomic.startWrite()
            try {
                out.write(JSONArray(list).toString().toByteArray(Charsets.UTF_8))
                atomic.finishWrite(out)
            } catch (e: Throwable) {
                atomic.failWrite(out)
                throw e
            }
            Log.d(TAG, "Saved ${file.name}")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save ${file.name}: $e")
            result.error("WRITE_ERROR", e.toString(), null)
        }
    }

    private fun readJsonList(call: MethodCall, result: MethodChannel.Result) {
        val file = allowedFile(call, result) ?: return
        try {
            result.success(if (file.exists()) file.readText() else "[]")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read ${file.name}: $e")
            result.error("READ_ERROR", e.toString(), null)
        }
    }

    private fun startMonitoringService() {
        AppPrefs.setServiceEnabled(this, true)
        startForegroundService(Intent(this, MonitoringForegroundService::class.java))
    }

    private fun stopMonitoringService() {
        AppPrefs.setServiceEnabled(this, false)
        RestartReceiver.cancelRestart(this)
        stopService(Intent(this, MonitoringForegroundService::class.java))
    }

    private fun getServiceStatus(): Map<String, Any> {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return mapOf(
            "serviceEnabled" to AppPrefs.isServiceEnabled(this),
            "notificationAccess" to ServiceWatchdog.hasNotificationAccess(this),
            "listenerConnected" to MyNotificationListenerService.isConnected,
            "ignoringBatteryOptimizations" to pm.isIgnoringBatteryOptimizations(packageName),
            "exactAlarms" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()),
            "sdk" to Build.VERSION.SDK_INT
        )
    }

    /**
     * Tries to open the manufacturer-specific "autostart / background activity" screen and falls
     * back to the app details page. Returns true if a manufacturer-specific screen was opened,
     * false if only the generic app page was.
     */
    private fun openAutoStartSettings(): Boolean {
        val candidates = listOf(
            // Xiaomi / Redmi / POCO
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            // Huawei / Honor
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            // Oppo / Realme
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            // Vivo / iQOO
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            // OnePlus
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            // Samsung (Device care -> Battery)
            "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
            "com.samsung.android.lool" to "com.samsung.android.sm.ui.battery.BatteryActivity",
            // Asus
            "com.asus.mobilemanager" to "com.asus.mobilemanager.autostart.AutoStartActivity"
        )
        for ((pkg, cls) in candidates) {
            try {
                startActivity(Intent().setClassName(pkg, cls).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {
                // This screen does not exist on this device; try the next one.
            }
        }
        try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app settings: $e")
        }
        return false
    }
}
