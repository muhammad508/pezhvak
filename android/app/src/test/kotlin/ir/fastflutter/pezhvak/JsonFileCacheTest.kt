package ir.fastflutter.pezhvak

import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class JsonFileCacheTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private fun cacheOf(file: File, parseCalls: IntArray = IntArray(1)) =
        JsonFileCache({ file }, "default") { content ->
            parseCalls[0]++
            check(content != "broken") { "cannot parse" }
            content
        }

    @Test
    fun returnsTheDefaultWhileTheFileDoesNotExist() {
        val cache = cacheOf(File(tmp.root, "missing.json"))
        assertEquals("default", cache.get())
    }

    @Test
    fun parsesOnlyOnceWhileTheFileIsUnchanged() {
        val file = tmp.newFile("config.json").apply { writeText("one") }
        val parseCalls = IntArray(1)
        val cache = cacheOf(file, parseCalls)

        repeat(3) { assertEquals("one", cache.get()) }

        assertEquals(1, parseCalls[0])
    }

    @Test
    fun reloadsAfterTheFileChanges() {
        val file = tmp.newFile("config.json").apply { writeText("one") }
        val cache = cacheOf(file)
        assertEquals("one", cache.get())

        // A different length is enough to invalidate the cache even on coarse timestamps.
        file.writeText("second")

        assertEquals("second", cache.get())
    }

    @Test
    fun keepsTheLastGoodValueWhenTheFileBecomesCorrupt() {
        val file = tmp.newFile("config.json").apply { writeText("good") }
        val cache = cacheOf(file)
        assertEquals("good", cache.get())

        file.writeText("broken")

        assertEquals("good", cache.get())
    }

    @Test
    fun fallsBackToTheDefaultWhenTheFileIsDeleted() {
        val file = tmp.newFile("config.json").apply { writeText("good") }
        val cache = cacheOf(file)
        assertEquals("good", cache.get())

        file.delete()

        assertEquals("default", cache.get())
    }
}
