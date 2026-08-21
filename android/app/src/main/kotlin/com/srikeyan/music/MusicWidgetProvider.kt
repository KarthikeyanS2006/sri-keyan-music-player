package com.srikeyan.music

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class MusicWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_now_playing)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val title = prefs.getString("widget_title", "Not Playing") ?: "Not Playing"
            val artist = prefs.getString("widget_artist", "Sri Keyan Music") ?: "Sri Keyan Music"
            val isPlaying = prefs.getBoolean("widget_is_playing", false)
            val artUri = prefs.getString("widget_art_uri", null)

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_artist, artist)

            if (isPlaying) {
                views.setImageViewResource(R.id.widget_play_pause, android.R.drawable.ic_media_pause)
            } else {
                views.setImageViewResource(R.id.widget_play_pause, android.R.drawable.ic_media_play)
            }

            if (!artUri.isNullOrEmpty()) {
                try {
                    val uri = Uri.parse(artUri)
                    views.setImageViewUri(R.id.widget_album_art, uri)
                } catch (_: Exception) {}
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingLaunch = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_album_art, pendingLaunch)
            views.setOnClickPendingIntent(R.id.widget_title, pendingLaunch)
            views.setOnClickPendingIntent(R.id.widget_artist, pendingLaunch)

            val prevIntent = Intent(context, MusicWidgetReceiver::class.java).apply {
                action = "com.srikeyan.music.ACTION_PREV"
            }
            views.setOnClickPendingIntent(
                R.id.widget_prev,
                PendingIntent.getBroadcast(context, 1, prevIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )

            val playPauseIntent = Intent(context, MusicWidgetReceiver::class.java).apply {
                action = "com.srikeyan.music.ACTION_PLAY_PAUSE"
            }
            views.setOnClickPendingIntent(
                R.id.widget_play_pause,
                PendingIntent.getBroadcast(context, 2, playPauseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )

            val nextIntent = Intent(context, MusicWidgetReceiver::class.java).apply {
                action = "com.srikeyan.music.ACTION_NEXT"
            }
            views.setOnClickPendingIntent(
                R.id.widget_next,
                PendingIntent.getBroadcast(context, 3, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, MusicWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(componentName)
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }
    }
}
