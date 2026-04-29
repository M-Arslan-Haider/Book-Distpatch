//package com.metaxperts.GPS_Workforce_Monitor
//
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//
//class BootCompletedReceiver : BroadcastReceiver() {
//    override fun onReceive(context: Context, intent: Intent) {
//        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
//            // Check if user was clocked in before reboot
//            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
//            val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
//            val isFrozen = prefs.getBoolean("flutter.is_timer_frozen", false)
//
//            // Only restart if clocked in and not already frozen (event handled)
//            if (isClockedIn && !isFrozen) {
//                // Identity (deviceId, companyCode, empName) will be read from
//                // SharedPreferences by LocationMonitorService.onStartCommand()
//                // because the service now persists them on every start.
//                val serviceIntent = Intent(context, LocationMonitorService::class.java)
//                context.startForegroundService(serviceIntent)
//            }
//        }
//    }
//}
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
                // Identity (deviceId, companyCode, empName) will be read from
                // SharedPreferences by LocationMonitorService.onStartCommand()
                // because the service now persists them on every start.
                val serviceIntent = Intent(context, LocationMonitorService::class.java)
                context.startForegroundService(serviceIntent)

                // ✅ NEW: Agar overtime session active tha to OvertimeMonitorService bhi restart karo
                val otClockInTime = prefs.getString("overtime_session_clock_in_time", null)
                if (!otClockInTime.isNullOrEmpty()) {
                    android.util.Log.d("BootReceiver", "⏰ [OT] Restoring OvertimeMonitorService after boot")
                    val otIntent = Intent(context, OvertimeMonitorService::class.java)
                    context.startForegroundService(otIntent)
                }
            }
        }
    }
}