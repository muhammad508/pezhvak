package ir.fastflutter.pezhvak

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class JsonlFileTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private fun jsonl(maxEntries: Int = 3, slack: Int = 0) =
        JsonlFile(File(tmp.root, "log.jsonl"), maxEntries, slack)

    @Test
    fun startsEmptyAndDoesNotCreateTheFileUntilTheFirstAppend() {
        val log = jsonl()

        assertFalse(log.exists)
        assertTrue(log.readLines().isEmpty())
    }

    @Test
    fun readsLinesBackOldestFirstAndSkipsBlankOnes() {
        val log = jsonl(maxEntries = 10)
        log.append("a")
        log.append("b")
        File(tmp.root, "log.jsonl").appendText("\n\n")

        assertEquals(listOf("a", "b"), log.readLines())
    }

    @Test
    fun keepsOnlyTheNewestEntriesOnceTheCapIsExceeded() {
        val log = jsonl(maxEntries = 3, slack = 0)

        listOf("1", "2", "3", "4", "5").forEach(log::append)

        assertEquals(listOf("3", "4", "5"), log.readLines())
    }

    @Test
    fun replaceAllSwapsTheWholeContent() {
        val log = jsonl(maxEntries = 10)
        log.append("old")

        log.replaceAll(listOf("x", "y"))
        log.append("z")

        assertEquals(listOf("x", "y", "z"), log.readLines())
    }

    @Test
    fun clearEmptiesTheLogAndAllowsWritingAgain() {
        val log = jsonl(maxEntries = 10)
        log.append("a")

        log.clear()
        assertFalse(log.exists)

        log.append("b")
        assertEquals(listOf("b"), log.readLines())
    }

    @Test
    fun recoversWhenSomeoneDeletesTheFileBehindItsBack() {
        val log = jsonl(maxEntries = 10)
        log.append("a")
        File(tmp.root, "log.jsonl").delete()

        log.append("b")

        assertEquals(listOf("b"), log.readLines())
    }
}
