package ir.fastflutter.pezhvak

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class HistoryStoreTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private fun store(maxEntries: Int = 10) =
        HistoryStore(tmp.root, "history", maxEntries)

    private fun lines() =
        File(tmp.root, "history.jsonl").readLines().filter { it.isNotBlank() }

    private fun entry(i: Int) = JSONObject().put("n", i)

    @Test
    fun appendsOneJsonObjectPerLine() {
        val history = store()

        history.append(entry(1))
        history.append(entry(2))

        assertEquals(listOf(1, 2), lines().map { JSONObject(it).getInt("n") })
    }

    @Test
    fun keepsMultilineTextOnASingleLine() {
        store().append(JSONObject().put("text", "first\nsecond"))

        val saved = lines()
        assertEquals(1, saved.size)
        assertEquals("first\nsecond", JSONObject(saved.single()).getString("text"))
    }

    @Test
    fun trimsToTheCapOnceTheSlackIsExceeded() {
        val history = store(maxEntries = 10)

        // The store tolerates 500 extra records before it rewrites the file.
        repeat(511) { history.append(entry(it)) }

        val kept = lines().map { JSONObject(it).getInt("n") }
        assertEquals(10, kept.size)
        assertEquals(501, kept.first())
        assertEquals(510, kept.last())
    }

    @Test
    fun migratesTheLegacyArrayAndReversesItsOrder() {
        // The legacy format was a JSON array, newest record first.
        File(tmp.root, "history.json").writeText(
            JSONArray().put(entry(3)).put(entry(2)).put(entry(1)).toString()
        )

        store().append(entry(4))

        assertEquals(listOf(1, 2, 3, 4), lines().map { JSONObject(it).getInt("n") })
        assertFalse(File(tmp.root, "history.json").exists())
    }

    @Test
    fun repairsAFileWhoseLastWriteWasCutShort() {
        File(tmp.root, "history.jsonl").writeText("{\"n\":1}\n{\"n\":")

        store().append(entry(2))

        val saved = File(tmp.root, "history.jsonl").readLines()
        assertTrue(saved.last().contains("\"n\":2"))
        // The truncated record stays on its own line instead of corrupting the new one.
        assertEquals(2, saved.count { it.trim().endsWith("}") })
    }
}
