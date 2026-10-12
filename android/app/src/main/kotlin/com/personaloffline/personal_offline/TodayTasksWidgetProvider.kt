package com.personaloffline.personal_offline

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget layar utama "Tugas Hari Ini".
 *
 * Memasang header (judul + tombol chat) lalu sebuah collection widget berupa
 * `ListView` yang diisi [TodayTasksWidgetService]. Daftar bisa digulir dan
 * menampilkan semua tugas. Interaksi centang ditangani tiap baris (lihat
 * factory di `TodayTasksWidgetService.kt`).
 */
class TodayTasksWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(
                context.packageName,
                R.layout.today_tasks_widget,
            )

            val chatIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(
                    "${TodayTasksWidgetContract.SCHEME}://${TodayTasksWidgetContract.CHAT_HOST}",
                ),
            )
            views.setOnClickPendingIntent(R.id.widget_header, chatIntent)
            views.setOnClickPendingIntent(R.id.widget_chat_button, chatIntent)

            val serviceIntent =
                Intent(context, TodayTasksWidgetService::class.java).apply {
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(
                appWidgetId,
                R.id.widget_list,
            )
        }
    }
}
