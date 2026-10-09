package com.personaloffline.personal_offline

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Widget layar utama "Tugas Hari Ini".
 *
 * Membaca snapshot JSON dari SharedPreferences (ditulis lewat home_widget),
 * menggambar daftar tugas hari ini, dan memasang PendingIntent:
 * - ikon centang tiap baris -> [HomeWidgetBackgroundReceiver] (toggle selesai),
 * - tombol/header chat -> membuka layar Percakapan aplikasi.
 */
class TodayTasksWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val tasks = parseTasks(widgetData.getString(KEY_TASKS, null))

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.today_tasks_widget)

            val chatIntent =
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("$SCHEME://$CHAT_HOST"),
                )
            views.setOnClickPendingIntent(R.id.widget_header, chatIntent)
            views.setOnClickPendingIntent(R.id.widget_chat_button, chatIntent)

            views.removeAllViews(R.id.widget_tasks_container)
            if (tasks.isEmpty()) {
                views.setViewVisibility(R.id.widget_tasks_container, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_tasks_container, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty, View.GONE)
                tasks.take(MAX_TASKS).forEach { task ->
                    views.addView(R.id.widget_tasks_container, buildRow(context, task))
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun buildRow(context: Context, task: WidgetTask): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.today_tasks_widget_row)
        row.setTextViewText(R.id.widget_row_title, task.title)
        row.setImageViewResource(
            R.id.widget_row_check,
            if (task.done) R.drawable.widget_icon_done else R.drawable.widget_icon_pending,
        )
        if (task.time.isNullOrEmpty()) {
            row.setViewVisibility(R.id.widget_row_time, View.GONE)
        } else {
            row.setViewVisibility(R.id.widget_row_time, View.VISIBLE)
            row.setTextViewText(R.id.widget_row_time, task.time)
        }

        val toggleIntent =
            HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("$SCHEME://$TOGGLE_HOST?$TOGGLE_ID=${task.id}"),
            )
        row.setOnClickPendingIntent(R.id.widget_row_check, toggleIntent)
        row.setOnClickPendingIntent(R.id.widget_row_title, toggleIntent)
        return row
    }

    private fun parseTasks(raw: String?): List<WidgetTask> {
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

    private data class WidgetTask(
        val id: Int,
        val title: String,
        val time: String?,
        val done: Boolean,
    )

    companion object {
        private const val KEY_TASKS = "today_tasks_json"
        private const val SCHEME = "personaloffline"
        private const val CHAT_HOST = "chat"
        private const val TOGGLE_HOST = "toggle"
        private const val TOGGLE_ID = "id"
        private const val MAX_TASKS = 6
    }
}
