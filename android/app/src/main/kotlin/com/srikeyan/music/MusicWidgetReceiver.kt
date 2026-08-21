package com.srikeyan.music

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MusicWidgetReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val flutterIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("widget_action", action)
        }
        context.startActivity(flutterIntent)
    }
}
