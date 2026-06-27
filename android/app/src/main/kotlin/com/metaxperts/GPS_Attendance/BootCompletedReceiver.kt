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

                // ✅ POWER OFF BACKUP: Agar ACTION_SHUTDOWN ROM ne block kar diya tha to
                // BOOT_COMPLETED pe power off event save karo — PowerOffService app open par post karega
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

                    val time = java.text.SimpleDateFormat(
                        "yyyy-MM-dd'T'HH:mm:ss",
                        java.util.Locale.getDefault()
                    ).format(java.util.Date())

                    // Sirf tab save karo jab ACTION_SHUTDOWN ne pehle se save nahi kiya
                    val alreadySaved = prefs.getString("flutter.pending_power_off", null)
                    if (alreadySaved.isNullOrEmpty()) {
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