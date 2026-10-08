package ir.fastflutter.pezhvak

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Subscription state on the native side. Flutter writes the expiry date to
 * [StorageFiles.PREMIUM] (PremiumService.setExpiry); this reads the same file (cached) so that
 * premium features such as advanced rule options are not applied without a valid subscription.
 */
object PremiumStatus {
    private var cache: JsonFileCache<Long>? = null

    @Synchronized
    fun isPremium(context: Context): Boolean {
        val expiry = cache ?: createCache(context.applicationContext.filesDir).also { cache = it }
        return expiry.get() > System.currentTimeMillis()
    }

    // Takes the directory (not the Context) so the singleton never holds on to a component.
    private fun createCache(filesDir: File) =
        JsonFileCache({ File(filesDir, StorageFiles.PREMIUM) }, 0L, ::parseExpiry)

    private fun parseExpiry(content: String): Long {
        val value = JSONObject(content).optString("expiry", "")
        if (value.isBlank()) return 0L
        return try {
            // Dart's toIso8601String() has no offset for local times and a trailing Z for UTC.
            if (value.endsWith("Z")) {
                Instant.parse(value).toEpochMilli()
            } else {
                LocalDateTime.parse(value).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            }
        } catch (_: Exception) {
            0L
        }
    }
}
