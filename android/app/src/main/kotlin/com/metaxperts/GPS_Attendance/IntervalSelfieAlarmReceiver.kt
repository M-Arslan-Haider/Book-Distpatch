//// ═══════════════════════════════════════════════════════════════════════════════
//// FILE: android/app/src/main/kotlin/com/metaxperts/GPS_Workforce_Monitor/
////       IntervalSelfieAlarmReceiver.kt
////
//// BACKGROUND INTERVAL SELFIE NOTIFICATION HANDLER
////
//// What this does:
////   • Reads clock-in time + NOTIF_COUNT from FlutterSharedPreferences.
////   • Schedules exact AlarmManager alarms at 2-hour intervals after clock-in.
////   • When alarm fires (even if app is fully killed): shows a notification +
////     sets  flutter.interval_selfie_notif_pending = true  in SharedPrefs +
////     writes grace expiry timestamp so Flutter can restore the countdown.
////
//// HOW TO REGISTER:
////   In AndroidManifest.xml inside <application>:
////
////   <receiver
////       android:name=".IntervalSelfieAlarmReceiver"
////       android:exported="false" />
////
//// HOW TO SCHEDULE FROM KOTLIN (call from LocationMonitorService or MainActivity):
////
////   IntervalSelfieAlarmReceiver.scheduleAll(context)   // on clock-in
////   IntervalSelfieAlarmReceiver.cancelAll(context)      // on clock-out
////
//// HOW TO CALL FROM FLUTTER via MethodChannel:
////   In MainActivity.kt, add to the MethodChannel handler:
////     "scheduleIntervalSelfieAlarms" -> IntervalSelfieAlarmReceiver.scheduleAll(context)
////     "cancelIntervalSelfieAlarms"   -> IntervalSelfieAlarmReceiver.cancelAll(context)
////
//// ═══════════════════════════════════════════════════════════════════════════════
//
//package com.metaxperts.GPS_Workforce_Monitor
//
//import android.app.AlarmManager
//import android.app.NotificationChannel
//import android.app.NotificationManager
//import android.app.PendingIntent
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.os.Build
//import androidx.core.app.NotificationCompat
//
//import java.text.SimpleDateFormat
//import java.util.Calendar
//import java.util.Date
//import java.util.Locale
//import java.util.Random
//
//// ─── SharedPreferences constants ─────────────────────────────────────────────
//private const val PREFS_NAME          = "FlutterSharedPreferences"
//private const val KEY_CLOCKED_IN      = "flutter.isClockedIn"
//private const val KEY_NOTIF_COUNT     = "flutter.interval_selfie_notif_count"
//private const val KEY_NOTIF_TIME_MIN  = "flutter.interval_selfie_notif_time_min"
//private const val KEY_CLOCK_IN_TIME   = "flutter.interval_selfie_clock_in_time"
//private const val KEY_PENDING         = "flutter.interval_selfie_notif_pending"
//private const val KEY_GRACE_EXPIRY    = "flutter.interval_selfie_grace_expiry"
//private const val KEY_NOTIFS_FIRED    = "flutter.interval_selfie_notifs_fired"
//private const val KEY_SELFIE_DONE     = "flutter.interval_selfie_done_flag"
//private const val KEY_FROZEN          = "flutter.is_timer_frozen"
//
//// ─── Notification channel ─────────────────────────────────────────────────────
//private const val CHANNEL_ID   = "interval_selfie_channel"
//private const val CHANNEL_NAME = "Interval Selfie Verification"
//private const val CHANNEL_DESC = "Periodic selfie verification reminders during shift"
//
//// ─── Alarm request code base ──────────────────────────────────────────────────
//// Each notification index gets: BASE + index  (e.g. 4001, 4002, 4003)
//private const val ALARM_REQ_BASE = 4000
//
//// ─── Intent extras ────────────────────────────────────────────────────────────
//private const val EXTRA_NOTIF_INDEX   = "notif_index"
//private const val EXTRA_NOTIF_COUNT   = "notif_count"
//private const val EXTRA_NOTIF_TIME_MIN= "notif_time_min"
//
//// ─── Notification ID base ─────────────────────────────────────────────────────
//private const val NOTIF_ID_BASE = 9300
//
//class IntervalSelfieAlarmReceiver : BroadcastReceiver() {
//
//    override fun onReceive(context: Context, intent: Intent) {
//        val notifIndex   = intent.getIntExtra(EXTRA_NOTIF_INDEX,    0)
//        val notifCount   = intent.getIntExtra(EXTRA_NOTIF_COUNT,    0)
//        val notifTimeMin = intent.getIntExtra(EXTRA_NOTIF_TIME_MIN, 0)
//
//        android.util.Log.d("IntervalSelfie",
//            "═══════════════════════════════════════════════════════")
//        android.util.Log.d("IntervalSelfie",
//            "📸 [INTERVAL SELFIE] ✅ Alarm received")
//        android.util.Log.d("IntervalSelfie",
//            "📸 [INTERVAL SELFIE]   notifIndex   = $notifIndex")
//        android.util.Log.d("IntervalSelfie",
//            "📸 [INTERVAL SELFIE]   notifCount   = $notifCount")
//        android.util.Log.d("IntervalSelfie",
//            "📸 [INTERVAL SELFIE]   notifTimeMin = $notifTimeMin")
//        android.util.Log.d("IntervalSelfie",
//            "═══════════════════════════════════════════════════════")
//
//        if (notifIndex <= 0) {
//            android.util.Log.w("IntervalSelfie",
//                "⚠️ [INTERVAL SELFIE] Invalid notifIndex=$notifIndex — ignoring")
//            return
//        }
//
//        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//
//        // Guard: do not fire if user is not clocked in or timer is frozen
//        val isClockedIn = prefs.getBoolean(KEY_CLOCKED_IN, false)
//        val isFrozen    = prefs.getBoolean(KEY_FROZEN,     false)
//
//        android.util.Log.d("IntervalSelfie",
//            "📸 [INTERVAL SELFIE]   isClockedIn=$isClockedIn  isFrozen=$isFrozen")
//
//        if (!isClockedIn || isFrozen) {
//            android.util.Log.d("IntervalSelfie",
//                "📸 [INTERVAL SELFIE] Not clocked in or frozen — skipping notification")
//            return
//        }
//
//        // Guard: selfie already done for this interval
//        val selfieDone = prefs.getBoolean(KEY_SELFIE_DONE, false)
//        android.util.Log.d("IntervalSelfie",
//            "📸 [INTERVAL SELFIE]   selfieDone=$selfieDone")
//
//        // If selfie was done, we still allow the next interval notification
//        // (selfieDone is per-notification, cleared on next clock-in)
//
//        // Write pending flag + grace expiry to SharedPrefs
//        val now         = System.currentTimeMillis()
//        val expiryMs    = now + (notifTimeMin * 60 * 1000L)
//        val expiryStr   = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
//            .format(Date(expiryMs))
//        val firedCount  = ((prefs.all[KEY_NOTIFS_FIRED] as? Long)?.toInt() ?: prefs.getInt(KEY_NOTIFS_FIRED, 0)) + 1
//
//        val editor = prefs.edit()
//        editor.putBoolean(KEY_PENDING,       true)
//        editor.putString(KEY_GRACE_EXPIRY,   expiryStr)
//        editor.putInt(KEY_NOTIFS_FIRED,      firedCount)
//        editor.remove(KEY_SELFIE_DONE)   // reset for this new notification window
//        try { editor.commit() } catch (e: Exception) { editor.apply() }
//
//        android.util.Log.d("IntervalSelfie",
//            "💾 [INTERVAL SELFIE] SharedPrefs written:")
//        android.util.Log.d("IntervalSelfie",
//            "💾 [INTERVAL SELFIE]   pending=true  expiry=$expiryStr  fired=$firedCount")
//
//        // Show the notification
//        showNotification(context, notifIndex, notifCount, notifTimeMin)
//    }
//
//    // ═══════════════════════════════════════════════════════════════════════
//    // SHOW NOTIFICATION
//    // ═══════════════════════════════════════════════════════════════════════
//
//    private fun showNotification(
//        context: Context,
//        index: Int,
//        total: Int,
//        graceMin: Int
//    ) {
//        try {
//            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
//                    as NotificationManager
//
//            // Create channel (idempotent on Android 8+)
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                val channel = NotificationChannel(
//                    CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_MAX
//                ).apply {
//                    description      = CHANNEL_DESC
//                    enableVibration(true)
//                    vibrationPattern = longArrayOf(0, 400, 200, 400)
//                    enableLights(true)
//                    lightColor       = android.graphics.Color.CYAN
//                }
//                manager.createNotificationChannel(channel)
//                android.util.Log.d("IntervalSelfie",
//                    "✅ [INTERVAL SELFIE] Notification channel created/verified")
//            }
//
//            // Tap intent — opens the app (notification body tap)
//            val launchIntent = context.packageManager
//                .getLaunchIntentForPackage(context.packageName)
//                ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
//
//            val pendingIntent = PendingIntent.getActivity(
//                context,
//                NOTIF_ID_BASE + index,
//                launchIntent,
//                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//            )
//
//            // "Open Camera" action button intent
//            // Uses a separate request code so it gets its own PendingIntent.
//            // Flutter reads the extra "notification_action" == "open_camera" on resume.
//            val cameraIntent = context.packageManager
//                .getLaunchIntentForPackage(context.packageName)
//                ?.apply {
//                    flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//                    putExtra("notification_action", "open_camera")
//                }
//
//            val cameraPendingIntent = PendingIntent.getActivity(
//                context,
//                NOTIF_ID_BASE + index + 500,        // different request code from body tap
//                cameraIntent,
//                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//            )
//
//            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
//                .setContentTitle("📸 Interval Selfie Verification")
//                .setContentText(
//                    "Please take your verification selfie now ($index of $total)"
//                )
//                .setStyle(
//                    NotificationCompat.BigTextStyle().bigText(
//                        "Your attendance requires a selfie verification.\n" +
//                                "Notification $index of $total. " +
//                                "You have $graceMin minute(s) to complete this."
//                    )
//                )
//                .setSmallIcon(android.R.drawable.ic_menu_camera)
//                .setPriority(NotificationCompat.PRIORITY_MAX)   // MAX forces heads-up banner
//                .setCategory(NotificationCompat.CATEGORY_REMINDER)
//                .setAutoCancel(false)                           // stay until selfie done or grace ends
//                .setOngoing(false)
//                .setContentIntent(pendingIntent)
//                .setVibrate(longArrayOf(0, 400, 200, 400))
//                .setLights(android.graphics.Color.CYAN, 800, 400)
//                .setColor(android.graphics.Color.rgb(124, 58, 237))
//                .addAction(                                     // ← ACTION BUTTON
//                    android.R.drawable.ic_menu_camera,
//                    "Open Camera",
//                    cameraPendingIntent
//                )
//                .build()
//
//            manager.notify(NOTIF_ID_BASE + index, notification)
//
//            android.util.Log.d("IntervalSelfie",
//                "🔔 [INTERVAL SELFIE] Notification shown id=${NOTIF_ID_BASE + index}")
//
//        } catch (e: Exception) {
//            android.util.Log.e("IntervalSelfie",
//                "❌ [INTERVAL SELFIE] showNotification error: ${e.message}")
//        }
//    }
//
//    // ═══════════════════════════════════════════════════════════════════════════
//    // COMPANION — static helpers to schedule / cancel alarms
//    // ═══════════════════════════════════════════════════════════════════════════
//
//    companion object {
//
//        /**
//         * Schedule NOTIF_COUNT alarms at RANDOM times within each 2h slot.
//         *
//         * ⚠️  CALL ORDER IS CRITICAL:
//         *   Flutter MUST call _fetchPolicyFromApi() and save to SharedPrefs FIRST.
//         *   Then Flutter calls this via MethodChannel("scheduleIntervalSelfieAlarms").
//         *   DO NOT call this from onStartCommand() — SharedPrefs won't be ready yet.
//         *
//         * Strategy:
//         *   Slot #i  =  [(i-1)*120 … i*120) minutes after clock-in
//         *   Alarm fires at a random minute within that slot.
//         *   All alarms guaranteed to fire — none missed.
//         *
//         * Reads from SharedPreferences:
//         *   flutter.interval_selfie_clock_in_time  ("yyyy-MM-dd'T'HH:mm:ss" — written by Flutter)
//         *   flutter.interval_selfie_notif_count     (written by Flutter after API fetch)
//         *   flutter.interval_selfie_notif_time_min  (written by Flutter after API fetch)
//         */
//        fun scheduleAll(context: Context) {
//            try {
//                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//
//                val clockInStr   = prefs.getString(KEY_CLOCK_IN_TIME, "") ?: ""
//                val notifCount   = (prefs.all[KEY_NOTIF_COUNT]   as? Long)?.toInt() ?: prefs.getInt(KEY_NOTIF_COUNT,   0)
//                val notifTimeMin = (prefs.all[KEY_NOTIF_TIME_MIN] as? Long)?.toInt() ?: prefs.getInt(KEY_NOTIF_TIME_MIN, 0)
//
//                android.util.Log.d("IntervalSelfie", "")
//                android.util.Log.d("IntervalSelfie",
//                    "═══════════════════════════════════════════════════════")
//                android.util.Log.d("IntervalSelfie",
//                    "📸 [INTERVAL SELFIE] scheduleAll (RANDOM MODE)")
//                android.util.Log.d("IntervalSelfie",
//                    "📸 [INTERVAL SELFIE]   clockInStr   = \"$clockInStr\"")
//                android.util.Log.d("IntervalSelfie",
//                    "📸 [INTERVAL SELFIE]   notifCount   = $notifCount")
//                android.util.Log.d("IntervalSelfie",
//                    "📸 [INTERVAL SELFIE]   notifTimeMin = $notifTimeMin")
//
//                // ── DEBUG: dump all interval-selfie SharedPrefs keys ──────────
//                android.util.Log.d("IntervalSelfie",
//                    "📸 [INTERVAL SELFIE]   [DEBUG] All relevant SharedPrefs keys:")
//                for ((k, v) in prefs.all) {
//                    if (k.contains("interval_selfie") || k == "flutter.isClockedIn") {
//                        android.util.Log.d("IntervalSelfie",
//                            "📸 [INTERVAL SELFIE]     $k = $v")
//                    }
//                }
//                // ─────────────────────────────────────────────────────────────
//
//                android.util.Log.d("IntervalSelfie",
//                    "📸 [INTERVAL SELFIE]   Strategy     = random within each 2h slot")
//                android.util.Log.d("IntervalSelfie",
//                    "───────────────────────────────────────────────────────")
//
//                if (notifCount <= 0) {
//                    android.util.Log.w("IntervalSelfie",
//                        "⚠️ [INTERVAL SELFIE] notifCount=0 — nothing to schedule")
//                    return
//                }
//
//                val clockInMs: Long
//                if (clockInStr.isEmpty()) {
//                    android.util.Log.w("IntervalSelfie",
//                        "⚠️ [INTERVAL SELFIE] clockInStr empty — using now as clock-in time")
//                    clockInMs = System.currentTimeMillis()
//                } else {
//                    try {
//                        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
//                        clockInMs = sdf.parse(clockInStr)?.time ?: System.currentTimeMillis()
//                    } catch (e: Exception) {
//                        android.util.Log.e("IntervalSelfie",
//                            "❌ [INTERVAL SELFIE] Cannot parse clockInStr: \"$clockInStr\" — $e")
//                        return
//                    }
//                }
//
//                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//                val nowMs        = System.currentTimeMillis()
//                val rng          = Random()
//                var scheduled    = 0
//
//                for (i in 1..notifCount) {
//                    val slotStartMin = (i - 1) * 120
//                    val slotEndMin   = i * 120
//                    val randomOffsetMin = slotStartMin + rng.nextInt(slotEndMin - slotStartMin)
//
//                    val fireAtMs = clockInMs + (randomOffsetMin * 60 * 1000L)
//                    val diffMin  = ((fireAtMs - nowMs) / 60_000).toInt()
//                    val fireTime = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(fireAtMs))
//
//                    android.util.Log.d("IntervalSelfie",
//                        "📸 [INTERVAL SELFIE]   Alarm #$i:")
//                    android.util.Log.d("IntervalSelfie",
//                        "📸 [INTERVAL SELFIE]     slot         = ${slotStartMin}min – ${slotEndMin}min after clock-in")
//                    android.util.Log.d("IntervalSelfie",
//                        "📸 [INTERVAL SELFIE]     randomOffset = ${randomOffsetMin}min after clock-in")
//                    android.util.Log.d("IntervalSelfie",
//                        "📸 [INTERVAL SELFIE]     fireAt       = $fireTime  (in ${diffMin}min from now)")
//
//                    if (fireAtMs <= nowMs) {
//                        android.util.Log.d("IntervalSelfie",
//                            "📸 [INTERVAL SELFIE]     ↳ ⚠️ already past — skipped")
//                        continue
//                    }
//
//                    val alarmIntent = Intent(context, IntervalSelfieAlarmReceiver::class.java).apply {
//                        putExtra(EXTRA_NOTIF_INDEX,    i)
//                        putExtra(EXTRA_NOTIF_COUNT,    notifCount)
//                        putExtra(EXTRA_NOTIF_TIME_MIN, notifTimeMin)
//                    }
//
//                    val pi = PendingIntent.getBroadcast(
//                        context,
//                        ALARM_REQ_BASE + i,
//                        alarmIntent,
//                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//                    )
//
//                    when {
//                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
//                                alarmManager.canScheduleExactAlarms() ->
//                            alarmManager.setExactAndAllowWhileIdle(
//                                AlarmManager.RTC_WAKEUP, fireAtMs, pi)
//
//                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
//                            alarmManager.setAndAllowWhileIdle(
//                                AlarmManager.RTC_WAKEUP, fireAtMs, pi)
//
//                        else ->
//                            alarmManager.set(AlarmManager.RTC_WAKEUP, fireAtMs, pi)
//                    }
//
//                    scheduled++
//                    android.util.Log.d("IntervalSelfie",
//                        "📸 [INTERVAL SELFIE]     ↳ ✅ Alarm set — fires in ${diffMin}min at $fireTime")
//                }
//
//                android.util.Log.d("IntervalSelfie",
//                    "───────────────────────────────────────────────────────")
//                android.util.Log.d("IntervalSelfie",
//                    "📸 [INTERVAL SELFIE] Scheduled $scheduled / $notifCount alarm(s)")
//                android.util.Log.d("IntervalSelfie",
//                    "═══════════════════════════════════════════════════════")
//                android.util.Log.d("IntervalSelfie", "")
//
//            } catch (e: Exception) {
//                android.util.Log.e("IntervalSelfie",
//                    "❌ [INTERVAL SELFIE] scheduleAll error: ${e.message}")
//            }
//        }
//
//        /**
//         * Cancel all pending interval selfie alarms.
//         * Call on clock-out.
//         */
//        fun cancelAll(context: Context) {
//            try {
//                val prefs      = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                val notifCount = ((prefs.all[KEY_NOTIF_COUNT] as? Long)?.toInt() ?: prefs.getInt(KEY_NOTIF_COUNT, 0)).coerceAtLeast(10) // cancel up to 10 just in case
//
//                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//                var cancelled    = 0
//
//                // Cancel notifications 1 through notifCount (plus a buffer up to 10)
//                for (i in 1..maxOf(notifCount, 10)) {
//                    val alarmIntent = Intent(context, IntervalSelfieAlarmReceiver::class.java)
//                    val pi = PendingIntent.getBroadcast(
//                        context,
//                        ALARM_REQ_BASE + i,
//                        alarmIntent,
//                        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
//                    ) ?: continue
//
//                    alarmManager.cancel(pi)
//                    pi.cancel()
//                    cancelled++
//                }
//
//                android.util.Log.d("IntervalSelfie",
//                    "🛑 [INTERVAL SELFIE] cancelAll: cancelled $cancelled alarm(s)")
//
//                // Clear pending flags
//                val editor = prefs.edit()
//                editor.remove(KEY_PENDING)
//                editor.remove(KEY_GRACE_EXPIRY)
//                editor.remove(KEY_SELFIE_DONE)
//                editor.putInt(KEY_NOTIFS_FIRED, 0)
//                try { editor.commit() } catch (e: Exception) { editor.apply() }
//
//                android.util.Log.d("IntervalSelfie",
//                    "🛑 [INTERVAL SELFIE] SharedPrefs flags cleared")
//
//            } catch (e: Exception) {
//                android.util.Log.e("IntervalSelfie",
//                    "❌ [INTERVAL SELFIE] cancelAll error: ${e.message}")
//            }
//        }
//
//        /**
//         * Quick check: is there a pending interval selfie notification right now?
//         * Checks both the pending flag and that grace window has not expired.
//         */
//        fun hasPendingNotification(context: Context): Boolean {
//            return try {
//                val prefs     = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                val pending   = prefs.getBoolean(KEY_PENDING, false)
//                if (!pending) return false
//
//                val expiryStr = prefs.getString(KEY_GRACE_EXPIRY, "") ?: ""
//                if (expiryStr.isEmpty()) return false
//
//                val sdf    = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
//                val expiry = sdf.parse(expiryStr) ?: return false
//                val active = expiry.after(Date())
//
//                android.util.Log.d("IntervalSelfie",
//                    "🔍 [INTERVAL SELFIE] hasPendingNotification=$active (expiry=$expiryStr)")
//                active
//            } catch (e: Exception) {
//                android.util.Log.e("IntervalSelfie",
//                    "❌ [INTERVAL SELFIE] hasPendingNotification error: ${e.message}")
//                false
//            }
//        }
//    }
//}
//
//// ═══════════════════════════════════════════════════════════════════════════════
//// HOW TO HOOK INTO LocationMonitorService (optional — for deep background support)
////
//// In LocationMonitorService.handleCriticalEvent(), at the END where clockout
//// happens, add:
////   IntervalSelfieAlarmReceiver.cancelAll(applicationContext)
////
//// In LocationMonitorService.onStartCommand(), where clockedIn && !isFrozen:
////   IntervalSelfieAlarmReceiver.scheduleAll(applicationContext)
////
//// These two lines are safe no-ops if interval selfie is not configured (notifCount=0).
//// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// FILE: android/app/src/main/kotlin/com/metaxperts/GPS_Workforce_Monitor/
//       IntervalSelfieAlarmReceiver.kt
//
// BACKGROUND INTERVAL SELFIE NOTIFICATION HANDLER
//
// What this does:
//   • Reads clock-in time + NOTIF_COUNT from FlutterSharedPreferences.
//   • Schedules exact AlarmManager alarms at 2-hour intervals after clock-in.
//   • When alarm fires (even if app is fully killed): shows a notification +
//     sets  flutter.interval_selfie_notif_pending = true  in SharedPrefs +
//     writes grace expiry timestamp so Flutter can restore the countdown.
//
// HOW TO REGISTER:
//   In AndroidManifest.xml inside <application>:
//
//   <receiver
//       android:name=".IntervalSelfieAlarmReceiver"
//       android:exported="false" />
//
// HOW TO SCHEDULE FROM KOTLIN (call from LocationMonitorService or MainActivity):
//
//   IntervalSelfieAlarmReceiver.scheduleAll(context)   // on clock-in
//   IntervalSelfieAlarmReceiver.cancelAll(context)      // on clock-out
//
// HOW TO CALL FROM FLUTTER via MethodChannel:
//   In MainActivity.kt, add to the MethodChannel handler:
//     "scheduleIntervalSelfieAlarms" -> IntervalSelfieAlarmReceiver.scheduleAll(context)
//     "cancelIntervalSelfieAlarms"   -> IntervalSelfieAlarmReceiver.cancelAll(context)
//
// ═══════════════════════════════════════════════════════════════════════════════

package com.metaxperts.GPS_Workforce_Monitor

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

// ─── SharedPreferences constants ─────────────────────────────────────────────
private const val PREFS_NAME          = "FlutterSharedPreferences"
private const val KEY_CLOCKED_IN      = "flutter.isClockedIn"
private const val KEY_NOTIF_COUNT     = "flutter.interval_selfie_notif_count"
private const val KEY_NOTIF_TIME_MIN  = "flutter.interval_selfie_notif_time_min"
private const val KEY_CLOCK_IN_TIME   = "flutter.interval_selfie_clock_in_time"
private const val KEY_PENDING         = "flutter.interval_selfie_notif_pending"
private const val KEY_GRACE_EXPIRY    = "flutter.interval_selfie_grace_expiry"
private const val KEY_NOTIFS_FIRED    = "flutter.interval_selfie_notifs_fired"
private const val KEY_SELFIE_DONE     = "flutter.interval_selfie_done_flag"
private const val KEY_FROZEN          = "flutter.is_timer_frozen"
private const val KEY_CACHED_END_TIME = "flutter.cached_end_time"   // ✅ shift end wall-clock (e.g. "05:00 PM")

// ─── Notification channel ─────────────────────────────────────────────────────
private const val CHANNEL_ID   = "interval_selfie_channel"
private const val CHANNEL_NAME = "Interval Selfie Verification"
private const val CHANNEL_DESC = "Periodic selfie verification reminders during shift"

// ─── Alarm request code base ──────────────────────────────────────────────────
// Each notification index gets: BASE + index  (e.g. 4001, 4002, 4003)
private const val ALARM_REQ_BASE = 4000

// ─── Intent extras ────────────────────────────────────────────────────────────
private const val EXTRA_NOTIF_INDEX   = "notif_index"
private const val EXTRA_NOTIF_COUNT   = "notif_count"
private const val EXTRA_NOTIF_TIME_MIN= "notif_time_min"

// ─── Notification ID base ─────────────────────────────────────────────────────
private const val NOTIF_ID_BASE = 9300

class IntervalSelfieAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val notifIndex   = intent.getIntExtra(EXTRA_NOTIF_INDEX,    0)
        val notifCount   = intent.getIntExtra(EXTRA_NOTIF_COUNT,    0)
        val notifTimeMin = intent.getIntExtra(EXTRA_NOTIF_TIME_MIN, 0)

        android.util.Log.d("IntervalSelfie",
            "═══════════════════════════════════════════════════════")
        android.util.Log.d("IntervalSelfie",
            "📸 [INTERVAL SELFIE] ✅ Alarm received")
        android.util.Log.d("IntervalSelfie",
            "📸 [INTERVAL SELFIE]   notifIndex   = $notifIndex")
        android.util.Log.d("IntervalSelfie",
            "📸 [INTERVAL SELFIE]   notifCount   = $notifCount")
        android.util.Log.d("IntervalSelfie",
            "📸 [INTERVAL SELFIE]   notifTimeMin = $notifTimeMin")
        android.util.Log.d("IntervalSelfie",
            "═══════════════════════════════════════════════════════")

        if (notifIndex <= 0) {
            android.util.Log.w("IntervalSelfie",
                "⚠️ [INTERVAL SELFIE] Invalid notifIndex=$notifIndex — ignoring")
            return
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Guard: do not fire if user is not clocked in or timer is frozen
        val isClockedIn = prefs.getBoolean(KEY_CLOCKED_IN, false)
        val isFrozen    = prefs.getBoolean(KEY_FROZEN,     false)

        android.util.Log.d("IntervalSelfie",
            "📸 [INTERVAL SELFIE]   isClockedIn=$isClockedIn  isFrozen=$isFrozen")

        if (!isClockedIn || isFrozen) {
            android.util.Log.d("IntervalSelfie",
                "📸 [INTERVAL SELFIE] Not clocked in or frozen — skipping notification")
            return
        }

        // Guard: selfie already done for this interval
        val selfieDone = prefs.getBoolean(KEY_SELFIE_DONE, false)
        android.util.Log.d("IntervalSelfie",
            "📸 [INTERVAL SELFIE]   selfieDone=$selfieDone")

        // If selfie was done, we still allow the next interval notification
        // (selfieDone is per-notification, cleared on next clock-in)

        // ✅ NEW: Guard — skip notification if shift has already ended
        val nowMs        = System.currentTimeMillis()
        val nowTimeStr   = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(nowMs))
        val endTimeRaw   = prefs.getString(KEY_CACHED_END_TIME, "") ?: ""

        android.util.Log.d("IntervalSelfie",
            "⏰ [SHIFT GUARD] currentTime=$nowTimeStr  cached_end_time=\"$endTimeRaw\"")

        if (endTimeRaw.isNotEmpty()) {
            val shiftEndMs = parseShiftEndToMs(endTimeRaw)
            if (shiftEndMs != null) {
                val shiftEndStr = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(shiftEndMs))
                android.util.Log.d("IntervalSelfie",
                    "⏰ [SHIFT GUARD] shiftEndTime=$shiftEndStr  nowMs=$nowMs  shiftEndMs=$shiftEndMs")

                if (nowMs >= shiftEndMs) {
                    android.util.Log.d("IntervalSelfie",
                        "🚫 [SHIFT GUARD] ❌ Shift ENDED — notification SKIPPED (now=$nowTimeStr >= shiftEnd=$shiftEndStr)")
                    android.util.Log.d("IntervalSelfie",
                        "🚫 [SHIFT GUARD]   interval timer stopped — no button will show")
                    return
                } else {
                    android.util.Log.d("IntervalSelfie",
                        "✅ [SHIFT GUARD] Shift still active — notification will fire (now=$nowTimeStr  shiftEnd=$shiftEndStr)")
                }
            } else {
                android.util.Log.w("IntervalSelfie",
                    "⚠️ [SHIFT GUARD] Cannot parse end_time \"$endTimeRaw\" — proceeding without shift-end check")
            }
        } else {
            android.util.Log.w("IntervalSelfie",
                "⚠️ [SHIFT GUARD] cached_end_time is empty — proceeding without shift-end check")
        }

        // Write pending flag + grace expiry to SharedPrefs
        val now         = System.currentTimeMillis()
        val expiryMs    = now + (notifTimeMin * 60 * 1000L)
        val expiryStr   = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            .format(Date(expiryMs))
        val firedCount  = ((prefs.all[KEY_NOTIFS_FIRED] as? Long)?.toInt() ?: prefs.getInt(KEY_NOTIFS_FIRED, 0)) + 1

        val editor = prefs.edit()
        editor.putBoolean(KEY_PENDING,       true)
        editor.putString(KEY_GRACE_EXPIRY,   expiryStr)
        editor.putInt(KEY_NOTIFS_FIRED,      firedCount)
        editor.remove(KEY_SELFIE_DONE)   // reset for this new notification window
        try { editor.commit() } catch (e: Exception) { editor.apply() }

        android.util.Log.d("IntervalSelfie",
            "💾 [INTERVAL SELFIE] SharedPrefs written:")
        android.util.Log.d("IntervalSelfie",
            "💾 [INTERVAL SELFIE]   pending=true  expiry=$expiryStr  fired=$firedCount")

        // Show the notification
        showNotification(context, notifIndex, notifCount, notifTimeMin)

        // ✅ FIX: Notification API pe log karo — no other logic change
        NotificationApiLogger.log(
            context  = context,
            notificationTitle = "Interval Selfie Verification ($notifIndex of $notifCount)"
        )
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SHOW NOTIFICATION
    // ═══════════════════════════════════════════════════════════════════════

    private fun showNotification(
        context: Context,
        index: Int,
        total: Int,
        graceMin: Int
    ) {
        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager

            // Create channel (idempotent on Android 8+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_MAX
                ).apply {
                    description      = CHANNEL_DESC
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 400, 200, 400)
                    enableLights(true)
                    lightColor       = android.graphics.Color.CYAN
                }
                manager.createNotificationChannel(channel)
                android.util.Log.d("IntervalSelfie",
                    "✅ [INTERVAL SELFIE] Notification channel created/verified")
            }

            // Tap intent — opens the app (notification body tap)
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }

            val pendingIntent = PendingIntent.getActivity(
                context,
                NOTIF_ID_BASE + index,
                launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            // "Open Camera" action button intent
            // Uses a separate request code so it gets its own PendingIntent.
            // Flutter reads the extra "notification_action" == "open_camera" on resume.
            val cameraIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("notification_action", "open_camera")
                }

            val cameraPendingIntent = PendingIntent.getActivity(
                context,
                NOTIF_ID_BASE + index + 500,        // different request code from body tap
                cameraIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle("📸 Interval Selfie Verification")
                .setContentText(
                    "Please take your verification selfie now ($index of $total)"
                )
                .setStyle(
                    NotificationCompat.BigTextStyle().bigText(
                        "Your attendance requires a selfie verification.\n" +
                                "Notification $index of $total. " +
                                "You have $graceMin minute(s) to complete this."
                    )
                )
                .setSmallIcon(android.R.drawable.ic_menu_camera)
                .setPriority(NotificationCompat.PRIORITY_MAX)   // MAX forces heads-up banner
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(false)                           // stay until selfie done or grace ends
                .setOngoing(false)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 400, 200, 400))
                .setLights(android.graphics.Color.CYAN, 800, 400)
                .setColor(android.graphics.Color.rgb(124, 58, 237))
                .addAction(                                     // ← ACTION BUTTON
                    android.R.drawable.ic_menu_camera,
                    "Open Camera",
                    cameraPendingIntent
                )
                .build()

            manager.notify(NOTIF_ID_BASE + index, notification)

            android.util.Log.d("IntervalSelfie",
                "🔔 [INTERVAL SELFIE] Notification shown id=${NOTIF_ID_BASE + index}")

        } catch (e: Exception) {
            android.util.Log.e("IntervalSelfie",
                "❌ [INTERVAL SELFIE] showNotification error: ${e.message}")
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPANION — static helpers to schedule / cancel alarms
    // ═══════════════════════════════════════════════════════════════════════════

    companion object {

        /**
         * Schedule NOTIF_COUNT alarms at RANDOM times within each 2h slot.
         *
         * ⚠️  CALL ORDER IS CRITICAL:
         *   Flutter MUST call _fetchPolicyFromApi() and save to SharedPrefs FIRST.
         *   Then Flutter calls this via MethodChannel("scheduleIntervalSelfieAlarms").
         *   DO NOT call this from onStartCommand() — SharedPrefs won't be ready yet.
         *
         * Strategy:
         *   Slot #i  =  [(i-1)*120 … i*120) minutes after clock-in
         *   Alarm fires at a random minute within that slot.
         *   All alarms guaranteed to fire — none missed.
         *
         * Reads from SharedPreferences:
         *   flutter.interval_selfie_clock_in_time  ("yyyy-MM-dd'T'HH:mm:ss" — written by Flutter)
         *   flutter.interval_selfie_notif_count     (written by Flutter after API fetch)
         *   flutter.interval_selfie_notif_time_min  (written by Flutter after API fetch)
         */
        fun scheduleAll(context: Context) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

                val clockInStr   = prefs.getString(KEY_CLOCK_IN_TIME, "") ?: ""
                val notifCount   = (prefs.all[KEY_NOTIF_COUNT]   as? Long)?.toInt() ?: prefs.getInt(KEY_NOTIF_COUNT,   0)
                val notifTimeMin = (prefs.all[KEY_NOTIF_TIME_MIN] as? Long)?.toInt() ?: prefs.getInt(KEY_NOTIF_TIME_MIN, 0)
                val endTimeRaw   = prefs.getString(KEY_CACHED_END_TIME, "") ?: ""

                android.util.Log.d("IntervalSelfie", "")
                android.util.Log.d("IntervalSelfie",
                    "═══════════════════════════════════════════════════════")
                android.util.Log.d("IntervalSelfie",
                    "📸 [INTERVAL SELFIE] scheduleAll (SHIFT-AWARE EVEN MODE)")
                android.util.Log.d("IntervalSelfie",
                    "📸 [INTERVAL SELFIE]   clockInStr     = \"$clockInStr\"")
                android.util.Log.d("IntervalSelfie",
                    "📸 [INTERVAL SELFIE]   notifCount     = $notifCount")
                android.util.Log.d("IntervalSelfie",
                    "📸 [INTERVAL SELFIE]   notifTimeMin   = $notifTimeMin")
                android.util.Log.d("IntervalSelfie",
                    "📸 [INTERVAL SELFIE]   cached_end_time= \"$endTimeRaw\"")

                // ── DEBUG: dump all interval-selfie SharedPrefs keys ──────────
                android.util.Log.d("IntervalSelfie",
                    "📸 [INTERVAL SELFIE]   [DEBUG] All relevant SharedPrefs keys:")
                for ((k, v) in prefs.all) {
                    if (k.contains("interval_selfie") || k == "flutter.isClockedIn" || k == "flutter.cached_end_time") {
                        android.util.Log.d("IntervalSelfie",
                            "📸 [INTERVAL SELFIE]     $k = $v")
                    }
                }
                // ─────────────────────────────────────────────────────────────

                if (notifCount <= 0) {
                    android.util.Log.w("IntervalSelfie",
                        "⚠️ [INTERVAL SELFIE] notifCount=0 — nothing to schedule")
                    return
                }

                // ── Parse clock-in time ────────────────────────────────────────
                val clockInMs: Long
                if (clockInStr.isEmpty()) {
                    android.util.Log.w("IntervalSelfie",
                        "⚠️ [INTERVAL SELFIE] clockInStr empty — using now as clock-in time")
                    clockInMs = System.currentTimeMillis()
                } else {
                    try {
                        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                        clockInMs = sdf.parse(clockInStr)?.time ?: System.currentTimeMillis()
                    } catch (e: Exception) {
                        android.util.Log.e("IntervalSelfie",
                            "❌ [INTERVAL SELFIE] Cannot parse clockInStr: \"$clockInStr\" — $e")
                        return
                    }
                }

                // ── Parse shift end time ───────────────────────────────────────
                val shiftEndMs: Long? = if (endTimeRaw.isNotEmpty()) parseShiftEndToMs(endTimeRaw) else null

                val clockInStr2  = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(clockInMs))
                val shiftEndStr2 = if (shiftEndMs != null)
                    SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(shiftEndMs))
                else "N/A (no end_time)"

                android.util.Log.d("IntervalSelfie",
                    "⏰ [SHIFT-AWARE]   shiftStart    = $clockInStr2")
                android.util.Log.d("IntervalSelfie",
                    "⏰ [SHIFT-AWARE]   shiftEnd      = $shiftEndStr2")
                android.util.Log.d("IntervalSelfie",
                    "⏰ [SHIFT-AWARE]   notifCount    = $notifCount")

                // ── Calculate effective window ────────────────────────────────
                // Use shift end if available; otherwise fall back to 2h-per-slot behaviour
                val windowEndMs: Long = if (shiftEndMs != null && shiftEndMs > clockInMs) {
                    shiftEndMs
                } else {
                    // Fallback: use notifCount * 120 min window
                    clockInMs + (notifCount * 120 * 60 * 1000L)
                }

                val shiftDurationMs  = windowEndMs - clockInMs
                val shiftDurationMin = shiftDurationMs / 60_000L

                // Even-interval formula: divide shift into (notifCount+1) equal parts
                // Notif i fires at: clockIn + i * (shiftDuration / (notifCount+1))
                val intervalMin = shiftDurationMin / (notifCount + 1)

                android.util.Log.d("IntervalSelfie",
                    "⏰ [SHIFT-AWARE]   shiftDuration = ${shiftDurationMin}min")
                android.util.Log.d("IntervalSelfie",
                    "⏰ [SHIFT-AWARE]   intervalMin   = ${intervalMin}min  (= shiftDuration / (notifCount+1))")
                android.util.Log.d("IntervalSelfie",
                    "───────────────────────────────────────────────────────")

                // ── Log all calculated notification times before scheduling ───
                android.util.Log.d("IntervalSelfie",
                    "📅 [SHIFT-AWARE] Calculated notification times:")
                for (i in 1..notifCount) {
                    val offsetMs    = i * intervalMin * 60_000L
                    val fireAt      = clockInMs + offsetMs
                    val fireTimeStr = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(fireAt))
                    android.util.Log.d("IntervalSelfie",
                        "📅 [SHIFT-AWARE]   Notif #$i → $fireTimeStr  (${i * intervalMin}min after shift start)")
                }
                android.util.Log.d("IntervalSelfie",
                    "───────────────────────────────────────────────────────")

                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val nowMs        = System.currentTimeMillis()
                val nowTimeStr   = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(nowMs))
                var scheduled    = 0

                android.util.Log.d("IntervalSelfie",
                    "🕐 [SHIFT-AWARE]   currentTime   = $nowTimeStr")

                for (i in 1..notifCount) {
                    val offsetMs = i * intervalMin * 60_000L
                    val fireAtMs = clockInMs + offsetMs
                    val diffMin  = ((fireAtMs - nowMs) / 60_000).toInt()
                    val fireTime = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(fireAtMs))

                    android.util.Log.d("IntervalSelfie",
                        "📸 [INTERVAL SELFIE]   Alarm #$i:")
                    android.util.Log.d("IntervalSelfie",
                        "📸 [INTERVAL SELFIE]     fireAt       = $fireTime  (in ${diffMin}min from now)")

                    // Skip if already past
                    if (fireAtMs <= nowMs) {
                        android.util.Log.d("IntervalSelfie",
                            "📸 [INTERVAL SELFIE]     ↳ ⚠️ already past — skipped")
                        continue
                    }

                    // Skip if at or after shift end
                    if (shiftEndMs != null && fireAtMs >= shiftEndMs) {
                        val shiftEndFmt = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(shiftEndMs))
                        android.util.Log.d("IntervalSelfie",
                            "📸 [INTERVAL SELFIE]     ↳ 🚫 fireAt=$fireTime >= shiftEnd=$shiftEndFmt — SKIPPED (outside shift)")
                        continue
                    }

                    val alarmIntent = Intent(context, IntervalSelfieAlarmReceiver::class.java).apply {
                        putExtra(EXTRA_NOTIF_INDEX,    i)
                        putExtra(EXTRA_NOTIF_COUNT,    notifCount)
                        putExtra(EXTRA_NOTIF_TIME_MIN, notifTimeMin)
                    }

                    val pi = PendingIntent.getBroadcast(
                        context,
                        ALARM_REQ_BASE + i,
                        alarmIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    when {
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                                alarmManager.canScheduleExactAlarms() ->
                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP, fireAtMs, pi)

                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                            alarmManager.setAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP, fireAtMs, pi)

                        else ->
                            alarmManager.set(AlarmManager.RTC_WAKEUP, fireAtMs, pi)
                    }

                    scheduled++
                    android.util.Log.d("IntervalSelfie",
                        "📸 [INTERVAL SELFIE]     ↳ ✅ Alarm set — fires in ${diffMin}min at $fireTime")
                }

                android.util.Log.d("IntervalSelfie",
                    "───────────────────────────────────────────────────────")
                android.util.Log.d("IntervalSelfie",
                    "📸 [INTERVAL SELFIE] Scheduled $scheduled / $notifCount alarm(s) (within shift window)")
                android.util.Log.d("IntervalSelfie",
                    "═══════════════════════════════════════════════════════")
                android.util.Log.d("IntervalSelfie", "")

            } catch (e: Exception) {
                android.util.Log.e("IntervalSelfie",
                    "❌ [INTERVAL SELFIE] scheduleAll error: ${e.message}")
            }
        }

        /**
         * Cancel all pending interval selfie alarms.
         * Call on clock-out.
         */
        fun cancelAll(context: Context) {
            try {
                val prefs      = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val notifCount = ((prefs.all[KEY_NOTIF_COUNT] as? Long)?.toInt() ?: prefs.getInt(KEY_NOTIF_COUNT, 0)).coerceAtLeast(10) // cancel up to 10 just in case

                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                var cancelled    = 0

                // Cancel notifications 1 through notifCount (plus a buffer up to 10)
                for (i in 1..maxOf(notifCount, 10)) {
                    val alarmIntent = Intent(context, IntervalSelfieAlarmReceiver::class.java)
                    val pi = PendingIntent.getBroadcast(
                        context,
                        ALARM_REQ_BASE + i,
                        alarmIntent,
                        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                    ) ?: continue

                    alarmManager.cancel(pi)
                    pi.cancel()
                    cancelled++
                }

                android.util.Log.d("IntervalSelfie",
                    "🛑 [INTERVAL SELFIE] cancelAll: cancelled $cancelled alarm(s)")

                // Clear pending flags
                val editor = prefs.edit()
                editor.remove(KEY_PENDING)
                editor.remove(KEY_GRACE_EXPIRY)
                editor.remove(KEY_SELFIE_DONE)
                editor.putInt(KEY_NOTIFS_FIRED, 0)
                try { editor.commit() } catch (e: Exception) { editor.apply() }

                android.util.Log.d("IntervalSelfie",
                    "🛑 [INTERVAL SELFIE] SharedPrefs flags cleared")

            } catch (e: Exception) {
                android.util.Log.e("IntervalSelfie",
                    "❌ [INTERVAL SELFIE] cancelAll error: ${e.message}")
            }
        }

        /**
         * ✅ NEW: Parse "cached_end_time" (e.g. "12:00 PM" / "17:00" / "5:00 PM")
         * and build a Long epoch-ms for TODAY at that wall-clock hour:minute.
         * Returns null if parsing fails.
         */
        private fun parseShiftEndToMs(raw: String): Long? {
            return try {
                val upper   = raw.trim().uppercase()
                val isPM    = upper.contains("PM")
                val isAM    = upper.contains("AM")
                val cleaned = upper.replace("PM", "").replace("AM", "").trim()
                val parts   = cleaned.split(":")
                if (parts.size < 2) return null

                var hour   = parts[0].trim().toIntOrNull() ?: return null
                val minute = parts[1].trim().split(Regex("\\s+"))[0].toIntOrNull() ?: return null

                if (isPM && hour != 12) hour += 12
                if (isAM && hour == 12) hour  = 0

                val cal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE,      minute)
                    set(Calendar.SECOND,      0)
                    set(Calendar.MILLISECOND, 0)
                }
                cal.timeInMillis
            } catch (e: Exception) {
                android.util.Log.e("IntervalSelfie",
                    "❌ [SHIFT GUARD] parseShiftEndToMs error: ${e.message}  raw=\"$raw\"")
                null
            }
        }

        /**
         * Quick check: is there a pending interval selfie notification right now?
         * Checks both the pending flag and that grace window has not expired.
         */
        fun hasPendingNotification(context: Context): Boolean {
            return try {
                val prefs     = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val pending   = prefs.getBoolean(KEY_PENDING, false)
                if (!pending) return false

                val expiryStr = prefs.getString(KEY_GRACE_EXPIRY, "") ?: ""
                if (expiryStr.isEmpty()) return false

                val sdf    = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                val expiry = sdf.parse(expiryStr) ?: return false
                val active = expiry.after(Date())

                android.util.Log.d("IntervalSelfie",
                    "🔍 [INTERVAL SELFIE] hasPendingNotification=$active (expiry=$expiryStr)")
                active
            } catch (e: Exception) {
                android.util.Log.e("IntervalSelfie",
                    "❌ [INTERVAL SELFIE] hasPendingNotification error: ${e.message}")
                false
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOW TO HOOK INTO LocationMonitorService (optional — for deep background support)
//
// In LocationMonitorService.handleCriticalEvent(), at the END where clockout
// happens, add:
//   IntervalSelfieAlarmReceiver.cancelAll(applicationContext)
//
// In LocationMonitorService.onStartCommand(), where clockedIn && !isFrozen:
//   IntervalSelfieAlarmReceiver.scheduleAll(applicationContext)
//
// These two lines are safe no-ops if interval selfie is not configured (notifCount=0).
// ═══════════════════════════════════════════════════════════════════════════════