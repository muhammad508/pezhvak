package ir.fastflutter.pezhvak

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity

/**
 * Transparent trampoline started by the notification listener. It wakes the screen, then
 * launches [MainActivity] as an alarm and finishes immediately.
 */
class UnlockActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over the lock screen and turn the display on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        // Keep the screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Kept from the original implementation: marks this window as an overlay window
        // (needs the SYSTEM_ALERT_WINDOW permission the app already requests).
        window.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)

        // Hand over to the main activity, flagged as an alarm so it shows over the lock screen.
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("is_alarm", true)
        }
        startActivity(intent)

        finish()
    }
}
