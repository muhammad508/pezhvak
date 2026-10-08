package ir.fastflutter.pezhvak

import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile

/**
 * An append-only text file with one record per line, trimmed to the newest [maxEntries] lines.
 *
 * Appending is O(1): the file is only rewritten once the line count exceeds [maxEntries] plus
 * [slack], so the cost of trimming is spread over many appends.
 */
internal class JsonlFile(
    private val file: File,
    private val maxEntries: Int,
    private val slack: Int
) {
    private val tmpFile = File(file.parentFile, "${file.name}.tmp")
    private var count = -1

    val exists: Boolean get() = file.exists()

    @Synchronized
    fun append(line: String) {
        // Prepare again when the file vanished (Flutter clears histories by deleting them).
        if (count < 0 || !file.exists()) prepare()
        // Records are single-line JSON (JSONObject.toString escapes newlines).
        FileOutputStream(file, true).use { it.write((line + "\n").toByteArray(Charsets.UTF_8)) }
        count++
        if (count > maxEntries + slack) trim()
    }

    /** Non-blank lines, oldest first. */
    @Synchronized
    fun readLines(): List<String> =
        if (file.exists()) file.readLines(Charsets.UTF_8).filter { it.isNotBlank() } else emptyList()

    /** Replaces the whole content atomically (temp file, then rename). */
    @Synchronized
    fun replaceAll(lines: List<String>) {
        tmpFile.writeText(lines.joinToString("\n", postfix = "\n"), Charsets.UTF_8)
        if (!tmpFile.renameTo(file)) {
            file.writeText(tmpFile.readText(Charsets.UTF_8), Charsets.UTF_8)
            tmpFile.delete()
        }
        count = lines.size
    }

    @Synchronized
    fun clear() {
        file.delete()
        count = 0
    }

    /** Makes sure the file ends with a newline and counts its lines. */
    private fun prepare() {
        if (file.exists()) {
            ensureTrailingNewline()
            count = readLines().size
        } else {
            count = 0
        }
    }

    // If the last write was cut short, the partial line would otherwise merge with the next record.
    private fun ensureTrailingNewline() {
        try {
            RandomAccessFile(file, "rw").use { raf ->
                if (raf.length() == 0L) return
                raf.seek(raf.length() - 1)
                if (raf.read() != '\n'.code) {
                    raf.seek(raf.length())
                    raf.write('\n'.code)
                }
            }
        } catch (_: Exception) {
            // Best effort: a missing newline only costs the one record that follows.
        }
    }

    private fun trim() {
        val lines = readLines()
        if (lines.size > maxEntries) replaceAll(lines.takeLast(maxEntries)) else count = lines.size
    }
}
