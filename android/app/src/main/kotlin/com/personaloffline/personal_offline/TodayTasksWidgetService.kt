package com.personaloffline.personal_offline

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Menyediakan daftar tugas yang bisa digulir (scroll) untuk widget layar utama.
 *
 * Memakai pola collection widget Android: [TodayTasksWidgetService] memberi
 * [RemoteViewsFactory] ke `ListView` di `today_tasks_widget.xml`, sehingga
 * seluruh tugas tampil dan dapat digulir tanpa batas jumlah baris.
 */
class TodayTasksWidgetService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TodayTasksRemoteViewsFactory(applicationContext)
}

private class TodayTasksRemoteViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private val preferences: SharedPreferences = HomeWidgetPlugin.getData(context)
    private var tasks: List<WidgetTask> = emptyList()

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        tasks = parseWidgetTasks(
            preferences.getString(TodayTasksWidgetContract.KEY_TASKS, null),
        )
    }

    override fun onDestroy() {
        tasks = emptyList()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks[position]
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

        val toggleIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse(
                "${TodayTasksWidgetContract.SCHEME}://${TodayTasksWidgetContract.TOGGLE_HOST}" +
                    "?${TodayTasksWidgetContract.TOGGLE_ID}=${task.id}",
            ),
        )
        row.setOnClickPendingIntent(R.id.widget_row_check, toggleIntent)
        row.setOnClickPendingIntent(R.id.widget_row_title, toggleIntent)
        return row
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = tasks[position].id.toLong()

    override fun hasStableIds(): Boolean = true
}
