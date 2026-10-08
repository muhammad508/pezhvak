package ir.fastflutter.pezhvak

import java.io.File

/**
 * In-memory cache for a config file. The file is re-read from disk only when its lastModified/length change.
 * If the file is half-written or corrupt, the last good value is returned.
 */
class JsonFileCache<T>(
    private val file: () -> File,
    private val default: T,
    private val parse: (String) -> T
) {
    private var stampModified = -1L
    private var stampLength = -1L
    private var value: T = default

    @Synchronized
    fun get(): T {
        val f = file()
        if (!f.exists()) {
            stampModified = -1L
            stampLength = -1L
            value = default
            return value
        }
        val modified = f.lastModified()
        val length = f.length()
        if (modified == stampModified && length == stampLength) return value
        try {
            value = parse(f.readText())
            stampModified = modified
            stampLength = length
        } catch (_: Exception) {
            // Corrupt or half-written: keep the previous value and retry on the next read.
        }
        return value
    }
}
