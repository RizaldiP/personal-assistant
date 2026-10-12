package com.personaloffline.personal_offline

import org.json.JSONArray

/**
 * Kontrak data widget "Tugas Hari Ini".
 *
 * Kunci SharedPreferences sama dengan yang ditulis `home_widget`
 * (`HomeWidgetPlugin.PREFERENCES`) dan di-encode Dart lewat
 * `today_tasks_codec.dart`, sehingga provider, service, dan callback Dart
 * memakai snapshot JSON yang sama.
 */
internal object TodayTasksWidgetContract {
    const val KEY_TASKS = "today_tasks_json"
    const val SCHEME = "personaloffline"
    const val CHAT_HOST = "chat"
    const val TOGGLE_HOST = "toggle"
    const val TOGGLE_ID = "id"
}

/** Satu baris tugas pada widget. */
internal data class WidgetTask(
    val id: Int,
    val title: String,
    val time: String?,
    val done: Boolean,
)

/** Mengurai snapshot JSON tugas; aman terhadap data kosong/rusak. */
internal fun parseWidgetTasks(raw: String?): List<WidgetTask> {
    if (raw.isNullOrEmpty()) return emptyList()
    return try {
        val array = JSONArray(raw)
        val result = ArrayList<WidgetTask>(array.length())
        for (index in 0 until array.length()) {
            val obj = array.optJSONObject(index) ?: continue
            val id = obj.optInt("i", Int.MIN_VALUE)
            val title = obj.optString("t", "")
            if (id == Int.MIN_VALUE || title.isEmpty()) continue
            result.add(
                WidgetTask(
                    id = id,
                    title = title,
                    time = obj.optString("m", "").ifEmpty { null },
                    done = obj.optBoolean("d", false),
                ),
            )
        }
        result
    } catch (exception: Exception) {
        emptyList()
    }
}
