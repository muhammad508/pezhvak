package ir.fastflutter.pezhvak

import org.json.JSONObject

const val PRIORITY_URGENT = "urgent"
const val PRIORITY_NORMAL = "normal"
const val PRIORITY_SILENT = "silent"

/**
 * Advanced options of a single rule (keyword or title). Premium feature.
 * Stored in rules.json under the key "k:<text>" or "t:<text>".
 */
data class RuleOptions(
    val priority: String = PRIORITY_NORMAL,
    val sound: String = "",
    val vibration: String = "off",
    val repeat: Boolean = false,
    val repeatMinutes: Int = 2,
    val excludes: List<String> = emptyList(),
    val schedule: JSONObject? = null,
    val ignoreGlobalSchedule: Boolean = false
)

/** A rule that matched a notification; kind is one of keyword, title or app. */
data class MatchedRule(val kind: String, val text: String, val options: RuleOptions) {
    val rank: Int
        get() = when (options.priority) {
            PRIORITY_URGENT -> 0
            PRIORITY_SILENT -> 2
            else -> 1
        }
}

fun parseRuleOptions(content: String): Map<String, RuleOptions> {
    val root = JSONObject(content)
    val map = HashMap<String, RuleOptions>()
    val keys = root.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        val o = root.optJSONObject(key) ?: continue
        val excludesArr = o.optJSONArray("excludes")
        val excludes = if (excludesArr == null) emptyList() else
            (0 until excludesArr.length()).map { excludesArr.optString(it, "") }.filter { it.isNotBlank() }
        map[key] = RuleOptions(
            priority = o.optString("priority", PRIORITY_NORMAL),
            sound = o.optString("sound", ""),
            vibration = o.optString("vibration", "off"),
            repeat = o.optBoolean("repeat", false),
            repeatMinutes = o.optInt("repeat_minutes", 2).coerceIn(1, 30),
            excludes = excludes,
            schedule = o.optJSONObject("schedule"),
            ignoreGlobalSchedule = o.optBoolean("ignore_global_schedule", false)
        )
    }
    return map
}
