package ir.fastflutter.pezhvak

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Stores a history as JSONL (one record per line, oldest first) in `<name>.jsonl`.
 * A legacy `<name>.json` array (newest first) is migrated on first use.
 */
class HistoryStore(dir: File, private val name: String, maxEntries: Int) {
    private val jsonl = JsonlFile(File(dir, "$name.jsonl"), maxEntries, SLACK)
    private val legacyFile = File(dir, "$name.json")

    @Synchronized
    fun append(entry: JSONObject) {
        try {
            // This is where the legacy array gets migrated, on the first write after an update.
            if (!jsonl.exists && legacyFile.exists()) migrateLegacy()
            jsonl.append(entry.toString())
        } catch (e: Exception) {
            Log.e(TAG, "append failed ($name): $e")
        }
    }

    private fun migrateLegacy() {
        try {
            val array = JSONArray(legacyFile.readText())
            // The legacy file was newest-first; JSONL is oldest-first.
            val lines = (array.length() - 1 downTo 0).mapNotNull { array.optJSONObject(it)?.toString() }
            jsonl.replaceAll(lines)
            legacyFile.delete()
        } catch (e: Exception) {
            Log.e(TAG, "legacy migration failed (${legacyFile.name}): $e")
        }
    }

    private companion object {
        const val TAG = "HistoryStore"

        /** Records tolerated above the cap before the file is rewritten. */
        const val SLACK = 500
    }
}
