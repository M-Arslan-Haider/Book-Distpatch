package com.metaxperts.bookdispatch

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isClockedIn = prefs.getBoolean("flutter.isClockedIn", false)
            val isFrozen = prefs.getBoolean("flutter.is_timer_frozen", false)

            if (isClockedIn && !isFrozen) {
                val serviceIntent = Intent(context, LocationMonitorService::class.java)
                context.startForegroundService(serviceIntent)

                val otClockInTime = prefs.getString("overtime_session_clock_in_time", null)
                if (!otClockInTime.isNullOrEmpty()) {
                    android.util.Log.d("BootReceiver", "⏰ [OT] Restoring OvertimeMonitorService after boot")
                    val otIntent = Intent(context, OvertimeMonitorService::class.java)
                    context.startForegroundService(otIntent)
                }

                try {
                    val empId = prefs.getString("flutter.userId", null)
                        ?: prefs.getString("flutter.user_id", null)
                        ?: prefs.getString("flutter.emp_id", null)
                        ?: prefs.getString("flutter.empId", null)
                        ?: ""

                    val empName = prefs.getString("flutter.userName", null)
                        ?: prefs.getString("flutter.user_name", null)
                        ?: prefs.getString("flutter.name", null)
                        ?: prefs.getString("flutter.full_name", null)
                        ?: ""

                    val companyCode = prefs.getString("flutter.companyCode", null)
                        ?: prefs.getString("flutter.company_code", null)
                        ?: prefs.getString("flutter.COMPANY_CODE", null)
                        ?: ""

                    // ✅ FIX: Boot time ki jagah last_active_time use karo
                    // ACTION_SHUTDOWN ne already exact time save kiya hoga
                    // Agar nahi kiya (ROM ne block kiya) to last_active_time use karo
                    val alreadySaved = prefs.getString("flutter.pending_power_off", null)
                    if (alreadySaved.isNullOrEmpty()) {
                        val lastActiveTime = prefs.getString("flutter.last_active_time", null)
                        val time = if (!lastActiveTime.isNullOrEmpty()) {
                            lastActiveTime!! // App ka last 60-second checkpoint
                        } else {
                            java.text.SimpleDateFormat(
                                "yyyy-MM-dd'T'HH:mm:ss",
                                java.util.Locale.US
                            ).format(java.util.Date())
                        }

                        val json = """{"emp_id":"$empId","emp_name":"$empName","company_code":"$companyCode","power_off":"yes","event_time":"$time"}"""

                        prefs.edit()
                            .putString("flutter.pending_power_off", json)
                            .putString("flutter.pending_power_off_time", time)
                            .commit()

                        android.util.Log.d("BootReceiver", "✅ [POWER OFF BACKUP] Saved via BOOT_COMPLETED: $json")
                    } else {
                        android.util.Log.d("BootReceiver", "ℹ️ [POWER OFF BACKUP] Already saved by ACTION_SHUTDOWN — skipping")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("BootReceiver", "❌ [POWER OFF BACKUP] Error: ${e.message}")
                }
            }
        }
    }
}
