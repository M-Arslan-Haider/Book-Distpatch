package com.metaxperts.GPS_Workforce_Monitor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Check if user was clocked in before reboot
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val isFrozen = prefs.getBoolean("flutter.is_timer_frozen", false)

            // Only restart if clocked in and not already frozen (event handled)
            if (isClockedIn && !isFrozen) {
                val serviceIntent = Intent(context, LocationMonitorService::class.java)
                context.startForegroundService(serviceIntent)
            }
        }
    }
}