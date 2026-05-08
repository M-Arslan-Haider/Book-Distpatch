package com.metaxperts.GPS_Workforce_Monitor

// ════════════════════════════════════════════════════════════════════════════
//  GeofenceViolationNotificationService.kt
//
//  Standalone service — shows in-app / system notifications whenever a
//  geofence violation is written to SharedPreferences by the Flutter side.
//
//  ✅ Works when app is FOREGROUND  (service is already running)
//  ✅ Works when app is BACKGROUND  (foreground service keeps it alive)
//  ✅ Works when app is KILLED      (AlarmManager re-starts it every 15 s)
//
//  NO OTHER FILE IS MODIFIED.
//
//  ── AndroidManifest.xml additions required (inside <application>) ──────────
//
//  <service
//      android:name=".GeofenceViolationNotificationService"
//      android:enabled="true"
//      android:exported="false"
//      android:foregroundServiceType="location" />
//
//  <receiver
//      android:name=".GeofenceViolationNotificationService$BootAndAlarmReceiver"
//      android:enabled="true"
//      android:exported="true">
//      <intent-filter>
//          <action android:name="android.intent.action.BOOT_COMPLETED" />
//          <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
//          <action android:name="com.metaxperts.GPS_Workforce_Monitor.GEOFENCE_RESTART" />
//      </intent-filter>
//  </receiver>
//
//  ── MainActivity.kt / MainActivity.java — start the service once ───────────
//
//  GeofenceViolationNotificationService.startService(this)
//
// ════════════════════════════════════════════════════════════════════════════

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class GeofenceViolationNotificationService : Service() {

    // ── Channel IDs ───────────────────────────────────────────────────────────
    private val FG_CHANNEL_ID        = "geofence_monitor_fg_channel"
    private val VIOLATION_CHANNEL_ID = "geofence_violation_alert_channel"

    // ── Notification IDs ──────────────────────────────────────────────────────
    private val FG_NOTIFICATION_ID   = 3001   // foreground (silent, always shown)
    private val ALERT_NOTIFICATION_ID = 3002  // violation alert (heads-up)

    // ── SharedPreferences — must match Flutter's keys ─────────────────────────
    // Flutter's SharedPreferences plugin prepends "flutter." to every key.
    private val PREFS_NAME        = "FlutterSharedPreferences"
    private val KEY_VIOLATIONS    = "flutter.geofence_violations_today"  // JSON list

    // ── Poll interval ─────────────────────────────────────────────────────────
    private val POLL_INTERVAL_MS  = 5_000L   // check every 5 seconds

    // ── AlarmManager restart interval ─────────────────────────────────────────
    private val ALARM_INTERVAL_MS = 15_000L  // reschedule every 15 s after kill

    // ── Internal state ────────────────────────────────────────────────────────
    private val handler          = Handler(Looper.getMainLooper())
    private var pollRunnable: Runnable? = null
    private var isDestroyed      = false

    // Keep track of what we already notified about so we don't spam.
    // Key = violation_id, Value = last event_type we notified ("out" / "in")
    private val notifiedMap      = mutableMapOf<String, String>()

    // ── Wake-lock (optional — keeps CPU awake for the poll) ───────────────────
    private var wakeLock: android.os.PowerManager.WakeLock? = null

    // ═════════════════════════════════════════════════════════════════════════
    // COMPANION — public entry points
    // ═════════════════════════════════════════════════════════════════════════

    companion object {
        private const val ACTION_RESTART =
            "com.metaxperts.GPS_Workforce_Monitor.GEOFENCE_RESTART"
        private const val ALARM_REQUEST_CODE = 88

        /** Call once from MainActivity to start the service. */
        fun startService(context: Context) {
            try {
                val intent = Intent(context, GeofenceViolationNotificationService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                android.util.Log.d("GeoViolNotif", "✅ startService() called")
            } catch (e: Exception) {
                android.util.Log.e("GeoViolNotif", "❌ startService error: ${e.message}")
            }
        }

        /** Cancel the AlarmManager restart (call on logout/clockout if desired). */
        fun stopAlarm(context: Context) {
            try {
                val pi = buildAlarmPendingIntent(context, PendingIntent.FLAG_NO_CREATE)
                if (pi != null) {
                    (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
                    pi.cancel()
                }
            } catch (e: Exception) {
                android.util.Log.e("GeoViolNotif", "stopAlarm error: ${e.message}")
            }
        }

        private fun buildAlarmPendingIntent(context: Context, flags: Int): PendingIntent? {
            val intent = Intent(context, BootAndAlarmReceiver::class.java).apply {
                action = ACTION_RESTART
            }
            val finalFlags = flags or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getBroadcast(context, ALARM_REQUEST_CODE, intent, finalFlags)
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SERVICE LIFECYCLE
    // ═════════════════════════════════════════════════════════════════════════

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("GeoViolNotif", "🟢 Service onCreate")
        createNotificationChannels()
        acquireWakeLock()
        startForeground(FG_NOTIFICATION_ID, buildForegroundNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("GeoViolNotif", "▶️ onStartCommand — starting poll loop")
        isDestroyed = false
        startPolling()
        scheduleAlarmRestart()   // always (re)schedule so kill recovery is up-to-date
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // App was swiped away — AlarmManager will re-start us
        android.util.Log.d("GeoViolNotif", "⚠️ onTaskRemoved — alarm restart already scheduled")
        scheduleAlarmRestart()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isDestroyed = true
        pollRunnable?.let { handler.removeCallbacks(it) }
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        android.util.Log.d("GeoViolNotif", "🔴 Service onDestroy")
        super.onDestroy()
    }

    // ═════════════════════════════════════════════════════════════════════════
    // POLLING
    // ═════════════════════════════════════════════════════════════════════════

    private fun startPolling() {
        pollRunnable?.let { handler.removeCallbacks(it) }

        pollRunnable = object : Runnable {
            override fun run() {
                if (!isDestroyed) {
                    checkViolations()
                    handler.postDelayed(this, POLL_INTERVAL_MS)
                }
            }
        }
        handler.post(pollRunnable!!)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core check — reads violations from SharedPreferences and fires
    // notifications for any new "out" or newly-closed "in" events.
    // ─────────────────────────────────────────────────────────────────────────
    private fun checkViolations() {
        try {
            val prefs    = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawJson  = prefs.getString(KEY_VIOLATIONS, null) ?: return
            val today    = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

            val arr = JSONArray(rawJson)

            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)

                // Only today's violations
                val vDate = obj.optString("violation_date", "")
                if (vDate != today) continue

                val violationId = obj.optString("violation_id", "")
                if (violationId.isEmpty()) continue
                val empName     = obj.optString("emp_name", "Employee")
                val locName     = obj.optString("location_name", "assigned location")
                val outTime     = obj.optString("out_time", "")
                val inTime      = obj.optString("in_time", "")
                val isOpen      = inTime.isEmpty() || inTime == "null"

                val lastNotified = notifiedMap[violationId]

                if (isOpen && lastNotified != "out") {
                    // ── New exit — user left the geofence ─────────────────────
                    notifiedMap[violationId] = "out"
                    val friendlyOut = formatTime(outTime)
                    showViolationNotification(
                        title   = "⚠️ Location Violation",
                        body    = "$empName left \"$locName\" at $friendlyOut",
                        isExit  = true,
                        notifId = ALERT_NOTIFICATION_ID + i    // unique per row
                    )
                    android.util.Log.d("GeoViolNotif",
                        "🚨 EXIT notification fired → $violationId")

                } else if (!isOpen && lastNotified == "out") {
                    // ── Return event — user came back ─────────────────────────
                    notifiedMap[violationId] = "in"
                    val friendlyIn = formatTime(inTime)
                    showViolationNotification(
                        title   = "✅ Employee Returned",
                        body    = "$empName returned to \"$locName\" at $friendlyIn",
                        isExit  = false,
                        notifId = ALERT_NOTIFICATION_ID + i
                    )
                    android.util.Log.d("GeoViolNotif",
                        "✅ RETURN notification fired → $violationId")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("GeoViolNotif", "checkViolations error: ${e.message}")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // NOTIFICATIONS
    // ═════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 1. Silent foreground channel (just to keep service alive)
        nm.createNotificationChannel(
            NotificationChannel(
                FG_CHANNEL_ID,
                "Geofence Monitor",
                NotificationManager.IMPORTANCE_MIN          // completely silent
            ).apply {
                description       = "Silent channel — keeps geofence watcher alive"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
        )

        // 2. High-priority violation alert channel (heads-up)
        nm.createNotificationChannel(
            NotificationChannel(
                VIOLATION_CHANNEL_ID,
                "Geofence Violations",
                NotificationManager.IMPORTANCE_HIGH         // heads-up on screen
            ).apply {
                description    = "Alerts when an employee enters or exits a geofenced area"
                enableLights(true)
                lightColor     = android.graphics.Color.RED
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
            }
        )

        android.util.Log.d("GeoViolNotif", "📢 Notification channels created")
    }

    /** Silent foreground notification (required to keep service alive on Android O+). */
    private fun buildForegroundNotification(): Notification {
        return NotificationCompat.Builder(this, FG_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Geofence Monitor Active")
            .setContentText("Monitoring employee location boundaries")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    /** High-priority heads-up notification for a violation event. */
    private fun showViolationNotification(
        title   : String,
        body    : String,
        isExit  : Boolean,
        notifId : Int,
    ) {
        try {
            // Tap notification → open app
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent()
            val pi = PendingIntent.getActivity(
                this, notifId, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val color = if (isExit)
                android.graphics.Color.rgb(220, 53, 69)   // red
            else
                android.graphics.Color.rgb(40, 167, 69)   // green

            val notification = NotificationCompat.Builder(this, VIOLATION_CHANNEL_ID)
                .setSmallIcon(
                    if (isExit) android.R.drawable.ic_menu_compass
                    else        android.R.drawable.ic_menu_mylocation
                )
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setColor(color)
                .setAutoCancel(true)
                .setContentIntent(pi)
                .setVibrate(longArrayOf(0, 300, 200, 300))
                .build()

            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(notifId, notification)

            // ── POST notification log to API (offline-safe) ───────────────
            NotificationApiLogger.log(this, title)

        } catch (e: Exception) {
            android.util.Log.e("GeoViolNotif", "showViolationNotification error: ${e.message}")
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ALARM MANAGER — keeps service alive after app kill
    // ═════════════════════════════════════════════════════════════════════════

    private fun scheduleAlarmRestart() {
        try {
            val pi         = companion.buildAlarmPendingIntent(this, PendingIntent.FLAG_UPDATE_CURRENT)
                ?: return
            val triggerMs  = System.currentTimeMillis() + ALARM_INTERVAL_MS
            val alarmMgr   = getSystemService(Context.ALARM_SERVICE) as AlarmManager

            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    alarmMgr.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
                else ->
                    alarmMgr.set(AlarmManager.RTC_WAKEUP, triggerMs, pi)
            }
            android.util.Log.d("GeoViolNotif",
                "⏰ AlarmManager restart scheduled in ${ALARM_INTERVAL_MS / 1000}s")
        } catch (e: Exception) {
            android.util.Log.e("GeoViolNotif", "scheduleAlarmRestart error: ${e.message}")
        }
    }

    // Need a companion reference for the private buildAlarmPendingIntent
    private val companion get() = Companion

    // ═════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═════════════════════════════════════════════════════════════════════════

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            wakeLock = pm.newWakeLock(
                android.os.PowerManager.PARTIAL_WAKE_LOCK,
                "GeoViolNotif::WakeLock"
            ).apply { acquire(10 * 60 * 1000L) }   // max 10 min; auto-released
        } catch (e: Exception) {
            android.util.Log.w("GeoViolNotif", "WakeLock acquire failed: ${e.message}")
        }
    }

    /** Convert ISO-8601 or HH:mm:ss string to a readable "h:mm a" label. */
    private fun formatTime(raw: String): String {
        if (raw.isEmpty() || raw == "null") return "--:--"
        return try {
            // Try full ISO first, then time-only
            val sdfFull = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS", Locale.getDefault())
            val sdfTime = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
            val out     = SimpleDateFormat("hh:mm a", Locale.getDefault())
            val date    = runCatching { sdfFull.parse(raw) }.getOrNull()
                ?: runCatching { sdfTime.parse(raw) }.getOrNull()
                ?: return raw
            out.format(date)
        } catch (_: Exception) { raw }
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  INNER BroadcastReceiver — handles BOOT_COMPLETED + AlarmManager wakeup
    // ═════════════════════════════════════════════════════════════════════════

    class BootAndAlarmReceiver : BroadcastReceiver() {

        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action ?: return
            android.util.Log.d("GeoViolNotif",
                "📡 BootAndAlarmReceiver → action=$action")

            when (action) {
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED,
                ACTION_RESTART -> {
                    // Re-start the service so notifications keep working
                    startService(context)
                }
            }
        }
    }
}