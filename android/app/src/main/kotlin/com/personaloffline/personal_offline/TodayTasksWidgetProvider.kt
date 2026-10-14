package com.personaloffline.personal_offline

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
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

            // Klik pada baris collection TIDAK boleh memakai setOnClickPendingIntent
            // (Android mengabaikannya untuk child view item collection). Wajib pakai
            // template + setOnClickFillInIntent (lihat TodayTasksWidgetService.kt).
            // Template ini harus MUTABLE agar data URI dari fill-in ikut tergabung;
            // HomeWidgetBackgroundIntent bawaan memaksa FLAG_IMMUTABLE sehingga tidak
            // bisa dipakai di sini.
            val toggleTemplate =
                Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
                    action = TodayTasksWidgetContract.BACKGROUND_ACTION
                }
            var templateFlags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                templateFlags = templateFlags or PendingIntent.FLAG_MUTABLE
            }
            views.setPendingIntentTemplate(
                R.id.widget_list,
                PendingIntent.getBroadcast(context, 0, toggleTemplate, templateFlags),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(
                appWidgetId,
                R.id.widget_list,
            )
        }
    }
}
