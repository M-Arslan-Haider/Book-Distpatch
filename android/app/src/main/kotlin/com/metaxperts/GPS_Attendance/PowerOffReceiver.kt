package com.metaxperts.GPS_Workforce_Monitor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class PowerOffReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG              = "PowerOffReceiver"
        private const val PREFS_NAME       = "FlutterSharedPreferences"
        private const val KEY_POWER_OFF    = "flutter.pending_power_off"
        private const val KEY_POWER_OFF_TIME = "flutter.pending_power_off_time"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_SHUTDOWN) return

        Log.d(TAG, "ACTION_SHUTDOWN received — saving locally")


        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            // Emp data SharedPreferences se lo
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
                java.util.Locale.US
            ).format(java.util.Date())

            // JSON string bana ke save karo
            val json = """{"emp_id":"$empId","emp_name":"$empName","company_code":"$companyCode","power_off":"yes","event_time":"$time"}"""

            // commit() use karo — shutdown mein apply() kaam nahi karta
            prefs.edit()
                .putString(KEY_POWER_OFF, json)
                .putString(KEY_POWER_OFF_TIME, time)
                .commit()

            Log.d(TAG, "Power off event saved locally: $json")

        } catch (e: Exception) {
            Log.e(TAG, "PowerOffReceiver error: ${e.message}")
        }
    }
}