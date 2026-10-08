package ir.fastflutter.pezhvak

import android.app.Application

/** Application class: installs the crash/exit diagnostics at process start. */
class PezhvakApp : Application() {

    companion object {
        // The Application class loads when the process starts, so this is roughly the process start time.
        val processStartMs: Long = System.currentTimeMillis()
    }

    override fun onCreate() {
        super.onCreate()
        DiagnosticsLog.install(this)
    }
}
