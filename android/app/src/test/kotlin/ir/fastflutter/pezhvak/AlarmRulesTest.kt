package ir.fastflutter.pezhvak

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmRulesTest {

    @Test
    fun anEmptyOptionsObjectUsesTheDefaults() {
        val options = parseRuleOptions("""{"k:deposit": {}}""").getValue("k:deposit")

        assertEquals(PRIORITY_NORMAL, options.priority)
        assertEquals("off", options.vibration)
        assertFalse(options.repeat)
        assertTrue(options.excludes.isEmpty())
        assertNull(options.schedule)
        assertFalse(options.ignoreGlobalSchedule)
    }

    @Test
    fun readsEveryField() {
        val json = """
            {"t:Bank": {
              "priority": "urgent", "sound": "/s.mp3", "vibration": "strong",
              "repeat": true, "repeat_minutes": 5,
              "excludes": ["promo", " ", "ad"],
              "schedule": {"enabled": true, "start_hour": 9},
              "ignore_global_schedule": true
            }}
        """
        val options = parseRuleOptions(json).getValue("t:Bank")

        assertEquals(PRIORITY_URGENT, options.priority)
        assertEquals("/s.mp3", options.sound)
        assertEquals("strong", options.vibration)
        assertTrue(options.repeat)
        assertEquals(5, options.repeatMinutes)
        assertEquals(listOf("promo", "ad"), options.excludes)
        assertNotNull(options.schedule)
        assertTrue(options.ignoreGlobalSchedule)
    }

    @Test
    fun clampsTheRepeatIntervalToASaneRange() {
        val options = parseRuleOptions(
            """{"k:a": {"repeat_minutes": 0}, "k:b": {"repeat_minutes": 999}}"""
        )

        assertEquals(1, options.getValue("k:a").repeatMinutes)
        assertEquals(30, options.getValue("k:b").repeatMinutes)
    }

    @Test
    fun rankOrdersUrgentBeforeNormalBeforeSilent() {
        fun rule(priority: String) = MatchedRule("keyword", "x", RuleOptions(priority = priority))

        val sorted = listOf(rule(PRIORITY_SILENT), rule(PRIORITY_NORMAL), rule(PRIORITY_URGENT))
            .sortedBy { it.rank }
            .map { it.options.priority }

        assertEquals(listOf(PRIORITY_URGENT, PRIORITY_NORMAL, PRIORITY_SILENT), sorted)
    }
}
