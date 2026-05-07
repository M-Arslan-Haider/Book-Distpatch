package com.metaxperts.GPS_Workforce_Monitor

// ════════════════════════════════════════════════════════════════════════════
// OvertimeMonitorService.kt
//
// PURPOSE:
//   Kotlin-side overtime cap monitor — foreground / background / app-killed
//   teeno cases mein kaam karta hai.
//
// HOW IT WORKS:
//   1. Flutter OvertimeClockOutService.dart SharedPreferences mein save karta hai:
//        overtime_session_clock_in_time  (ISO-8601)
//        overtime_session_end_time       (ISO-8601)
//        cached_dep_id                   (department ID)
//
//   2. Yeh service:
//        • Har 10 seconds mein API call karta hai:
//            GET http://oracle.metaxperts.net/ords/gps_workforce/maxot/get?dep_id=XXX
//        • Response SharedPreferences mein store karta hai
//        • Bache hue time calculate karta hai
//        • Jab remaining == 0 → clockout keys likh ke Flutter ko handoff karta hai
//        • AlarmManager exact alarm set karta hai (process kill survive karta hai)
//        • Notification dikha ke stop ho jata hai
//
//   3. Jab app wapas khule → Flutter flutter.clockOutPending / flutter.hasFastClockOutData
//      check karta hai aur POST karta hai — koi Kotlin-side POST nahi.
//
//   4. Jab user dobara clock-in kare → Flutter phir se OvertimeClockOutService.start()
//      call karta hai → SharedPreferences update hota hai → OvertimeMonitorService ko
//      dobara start karo — nayi shift phir track hogi.
//
// MANIFEST mein add karo (android/app/src/main/AndroidManifest.xml):
//   <service
//       android:name=".OvertimeMonitorService"
//       android:enabled="true"
//       android:exported="false"
//       android:foregroundServiceType="location" />
//
// Flutter side se call karo (MethodChannel / platform channel, ya directly):
//   OvertimeMonitorService.start(context)         — session already prefs mein hai
//   OvertimeMonitorService.stop(context)           — clockout / cancel par
//
// BootCompletedReceiver.kt mein (agar overtime session restore bhi chahiye):
//   val isOtActive = prefs.getString("overtime_session_clock_in_time", null) != null
//   if (isClockedIn && !isFrozen && isOtActive) {
//       context.startForegroundService(Intent(context, OvertimeMonitorService::class.java))
//   }
// ════════════════════════════════════════════════════════════════════════════

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class OvertimeMonitorService : Service() {

    // ════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════

    private val TAG                   = "OvertimeMonitor"
    private val CHANNEL_ID            = "overtime_monitor_channel"
    private val CLOCKOUT_CHANNEL_ID   = "overtime_clockout_alert_channel"
    private val NOTIF_ID              = 3001
    private val CLOCKOUT_NOTIF_ID     = 3002
    private val ALARM_REQ_CODE        = 88

    /** Har 10 second mein API fetch — live data aya kare */
    private val FETCH_INTERVAL_MS     = 10_000L

    /** OT cap API endpoint */
    private val OT_API_BASE           = "http://oracle.metaxperts.net/ords/gps_workforce/maxot/get"

    // ── SharedPreferences ────────────────────────────────────────────────────
    private val PREFS_NAME            = "FlutterSharedPreferences"

    // Flutter standard keys (same as LocationMonitorService)
    private val KEY_IS_CLOCKED_IN     = "flutter.isClockedIn"
    private val KEY_IS_TIMER_FROZEN   = "flutter.is_timer_frozen"
    private val KEY_HAS_CRITICAL_EVT  = "flutter.has_critical_event_pending"
    private val KEY_EVT_TIMESTAMP     = "flutter.critical_event_timestamp"
    private val KEY_EVT_REASON        = "flutter.critical_event_reason"

    // OT session keys — Flutter OvertimeClockOutService.dart writes these
    private val KEY_OT_CLOCK_IN_TIME  = "overtime_session_clock_in_time"   // ISO-8601
    private val KEY_OT_END_TIME       = "overtime_session_end_time"         // ISO-8601
    private val KEY_DEP_ID            = "cached_dep_id"                     // department
    private val KEY_OT_CAP_RESPONSE   = "cached_ot_cap_api_response"        // raw JSON per dep
    private val KEY_OT_CAP_MINUTES    = "flutter.cached_ot_cap_minutes"     // parsed int
    private val KEY_OT_LAST_FETCH     = "flutter.ot_api_last_fetch"         // timestamp string
    private val KEY_OT_DONE_DATE      = "flutter.overtime_clockout_done_date"

    // ════════════════════════════════════════════════════════════════════════
    // COMPANION  — static helpers
    // ════════════════════════════════════════════════════════════════════════

    companion object {
        const val EXTRA_OT_ALARM_TRIGGER = "ot_alarm_trigger"
        const val EXTRA_DEVICE_ID        = "deviceId"
        const val EXTRA_COMPANY_CODE     = "companyCode"
        const val EXTRA_EMP_NAME         = "empName"

        /** Flutter → start overtime monitoring */
        fun start(context: Context) {
            try {
                val i = Intent(context, OvertimeMonitorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
                Log.d("OvertimeMonitor", "▶️ [OT] Service start() called")
            } catch (e: Exception) {
                Log.e("OvertimeMonitor", "❌ [OT] start() failed: ${e.message}")
            }
        }

        /** Flutter → stop (clock-out / cancel) */
        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, OvertimeMonitorService::class.java))
                Log.d("OvertimeMonitor", "⏹️ [OT] Service stop() called")
            } catch (e: Exception) {
                Log.e("OvertimeMonitor", "❌ [OT] stop() failed: ${e.message}")
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // MUTABLE STATE
    // ════════════════════════════════════════════════════════════════════════

    private lateinit var handler: Handler
    private var fetchRunnable: Runnable? = null
    private var isServiceDestroyed      = false

    private var wakeLock: PowerManager.WakeLock? = null

    /** Overtime clock-in time (read from prefs on start) */
    private var overtimeClockInTime: Date? = null

    /** Last successfully fetched cap (minutes) */
    private var cachedCapMinutes = 0

    /** Identity — read from prefs / intent */
    private var deviceId    = ""
    private var companyCode = ""
    private var empName     = ""
    private var depId       = ""

    private val sdfFull  = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
    private val sdfFull2 = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault())
    private val sdfDate  = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    private val sdfTime  = SimpleDateFormat("HH:mm:ss", Locale.getDefault())

    // ════════════════════════════════════════════════════════════════════════
    // SERVICE LIFECYCLE
    // ════════════════════════════════════════════════════════════════════════

    override fun onCreate() {
        super.onCreate()
        handler = Handler(Looper.getMainLooper())
        acquireWakeLock()

        logBlock("OvertimeMonitorService onCreate()")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "")
        Log.d(TAG, "── [OT] onStartCommand() ───────────────────────────────────────")

        createNotificationChannels()

        // ── Foreground notification (mandatory before anything else on O+) ──
        try {
            val notif = buildStatusNotification("Starting overtime monitor…")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(NOTIF_ID, notif)
            }
            Log.d(TAG, "✅ [OT] startForeground() OK")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [OT] startForeground() failed: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // ── Read identity ────────────────────────────────────────────────────
        deviceId    = intent?.getStringExtra(EXTRA_DEVICE_ID)?.takeIf    { it.isNotEmpty() }
            ?: prefStr(prefs, "user_name")
        companyCode = intent?.getStringExtra(EXTRA_COMPANY_CODE)?.takeIf { it.isNotEmpty() }
            ?: prefStr(prefs, "company_code")
        empName     = intent?.getStringExtra(EXTRA_EMP_NAME)?.takeIf     { it.isNotEmpty() }
            ?: prefStr(prefs, "emp_name")
        depId       = listOf(
            KEY_DEP_ID,
            "flutter.cached_dep_id",
            "flutter.$KEY_DEP_ID"
        ).firstNotNullOfOrNull { prefStr(prefs, it).takeIf { v -> v.isNotEmpty() } } ?: ""

        Log.d(TAG, "🔑 [OT] Identity → deviceId=$deviceId  company=$companyCode  depId=\"$depId\"")

        // ════════════════════════════════════════════════════════════════════
        // PATH A — AlarmManager wakeup (process was dead at OT end time)
        // ════════════════════════════════════════════════════════════════════
        val isAlarmTrigger = intent?.getBooleanExtra(EXTRA_OT_ALARM_TRIGGER, false) ?: false
        if (isAlarmTrigger) {
            Log.d(TAG, "")
            Log.d(TAG, "⏰ [OT ALARM] ── AlarmManager triggered onStartCommand ──────────")
            Log.d(TAG, "⏰ [OT ALARM] Checking if still clocked in…")

            val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
            val frozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

            Log.d(TAG, "⏰ [OT ALARM] isClockedIn=$clocked  isFrozen=$frozen")

            if (clocked && !frozen) {
                Log.d(TAG, "⏰ [OT ALARM] ✅ Firing overtime clockout via AlarmManager path")
                handler.postDelayed({ triggerOvertimeClockout() }, 300)
            } else {
                Log.d(TAG, "⏰ [OT ALARM] Already clocked out / frozen — no action needed")
                stopSelf()
            }
            return START_NOT_STICKY
        }

        // ════════════════════════════════════════════════════════════════════
        // PATH B — Normal start (from Flutter / BootReceiver)
        // ════════════════════════════════════════════════════════════════════

        val isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen    = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        Log.d(TAG, "📋 [OT] State → isClockedIn=$isClockedIn  isFrozen=$isFrozen")

        if (!isClockedIn || isFrozen) {
            Log.w(TAG, "⚠️ [OT] Not clocked in or already frozen — nothing to monitor. Stopping.")
            stopSelf()
            return START_NOT_STICKY
        }

        // ── Parse OT clock-in time ───────────────────────────────────────────
        val otClockInStr = listOf(
            KEY_OT_CLOCK_IN_TIME,
            "flutter.$KEY_OT_CLOCK_IN_TIME"
        ).firstNotNullOfOrNull { prefStr(prefs, it).takeIf { v -> v.isNotEmpty() } } ?: ""

        Log.d(TAG, "⏰ [OT] OT clock-in from prefs: \"$otClockInStr\"")

        overtimeClockInTime = if (otClockInStr.isNotEmpty()) {
            parseDate(otClockInStr).also {
                if (it != null) Log.d(TAG, "✅ [OT] OT clock-in parsed: $it")
                else Log.w(TAG, "⚠️ [OT] Could not parse OT clock-in — using now as fallback")
            } ?: Date()
        } else {
            Log.w(TAG, "⚠️ [OT] No OT clock-in key in prefs — using now as fallback")
            Date()
        }

        // ── Check existing saved OT end time (fast path) ─────────────────────
        val savedEndStr = listOf(
            KEY_OT_END_TIME,
            "flutter.$KEY_OT_END_TIME"
        ).firstNotNullOfOrNull { prefStr(prefs, it).takeIf { v -> v.isNotEmpty() } } ?: ""

        // ✅ FIX: savedEnd ko tabhi valid maano jab wo current clock-in ke BAAD ho.
        // Agar savedEnd <= overtimeClockInTime, matlab yeh PURANI session ka leftover hai.
        // Purani value se "overtime ended" notification nahin chahiye — ignore karo.
        val clockInMs  = overtimeClockInTime?.time ?: 0L
        val savedEnd   = if (savedEndStr.isNotEmpty()) parseDate(savedEndStr) else null
        val isCurrentSession = savedEnd != null && savedEnd.time > clockInMs

        if (isCurrentSession) {
            val remainMs = savedEnd!!.time - System.currentTimeMillis()
            Log.d(TAG, "💾 [OT] Saved OT end time: $savedEndStr  remaining: ${remainMs/1000}s")
            if (remainMs <= 0) {
                Log.d(TAG, "🔴 [OT] Saved OT end time ALREADY PASSED → immediate clockout")
                handler.postDelayed({ triggerOvertimeClockout() }, 500)
                return START_STICKY
            }
            // Pre-schedule alarm so we survive kill before first fetch completes
            scheduleOtAlarm(savedEnd.time)
        } else {
            if (savedEndStr.isNotEmpty()) {
                Log.d(TAG, "⚠️ [OT] Saved OT end time ($savedEndStr) belongs to a previous session — ignoring")
            }
            // Fall through: use cached cap to pre-schedule alarm for this new session
            // ✅ FIX: savedEndStr nahi mila — fresh clock-in ka case.
            // Cached cap se endTime estimate karo aur pre-schedule karo.
            // Agar cap bhi nahi mila to 4h fallback use karo — fetch loop sahi value set karega.
            // Yeh zaruri hai: agar API slow hai aur app kill ho jaye to clockout miss na ho.
            val cachedCap = prefs.getInt(KEY_OT_CAP_MINUTES, 0)
            val capToUse  = if (cachedCap > 0) cachedCap else 240  // 4h fallback
            val estimatedEnd = Date(overtimeClockInTime!!.time + capToUse * 60_000L)
            val remainMs     = estimatedEnd.time - System.currentTimeMillis()
            if (remainMs > 0) {
                scheduleOtAlarm(estimatedEnd.time)
                Log.d(TAG, "⏰ [OT] Pre-scheduled alarm at ${sdfFull.format(estimatedEnd)} " +
                        "(cap=${capToUse}min estimate — fetch loop will update)")
            } else {
                Log.d(TAG, "🔴 [OT] Estimated end time already passed → immediate clockout")
                handler.postDelayed({ triggerOvertimeClockout() }, 500)
                return START_STICKY
            }
        }

        Log.d(TAG, "")
        Log.d(TAG, "✅ [OT] All good — starting live 10-sec fetch loop")
        Log.d(TAG, "── [OT] onStartCommand() END ───────────────────────────────────")
        Log.d(TAG, "")

        startFetchLoop()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "📱 [OT] onTaskRemoved — scheduling service restart in 1s")
        super.onTaskRemoved(rootIntent)

        // ✅ FIX: App kill hone par service dobara start karo via AlarmManager.
        // OvertimeMonitorService foreground service hai lekin OEM aggressive killers
        // START_STICKY ke bawajood ise kill kar dete hain. AlarmManager restart ensure karta hai.
        val prefs   = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val frozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clocked && !frozen) {
            try {
                val restartIntent = Intent(applicationContext, OvertimeMonitorService::class.java)
                val pi = PendingIntent.getService(
                    applicationContext, ALARM_REQ_CODE + 1, restartIntent,
                    PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
                )
                val am          = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val triggerTime = android.os.SystemClock.elapsedRealtime() + 2_000L
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() ->
                        am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi)
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                        am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi)
                    else ->
                        am.set(AlarmManager.ELAPSED_REALTIME, triggerTime, pi)
                }
                Log.d(TAG, "⏰ [OT] Restart alarm set for 2s after task removal")
            } catch (e: Exception) {
                Log.e(TAG, "❌ [OT] onTaskRemoved restart error: ${e.message}")
            }
        } else {
            Log.d(TAG, "📱 [OT] onTaskRemoved — not clocked in / frozen, no restart needed")
        }
    }

    override fun onDestroy() {
        isServiceDestroyed = true
        fetchRunnable?.let { handler.removeCallbacks(it) }
        releaseWakeLock()
        Log.d(TAG, "⏹️ [OT] OvertimeMonitorService onDestroy()")
        super.onDestroy()
    }

    // ════════════════════════════════════════════════════════════════════════
    // FETCH LOOP  — har 10 seconds mein chalata hai
    // ════════════════════════════════════════════════════════════════════════

    private fun startFetchLoop() {
        fetchRunnable = object : Runnable {
            override fun run() {
                if (isServiceDestroyed) return

                val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clocked   = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                val frozen    = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

                Log.d(TAG, "")
                Log.d(TAG, "── [OT TICK] ${sdfTime.format(Date())} ──────────────────────────────────────")
                Log.d(TAG, "   isClockedIn=$clocked  isFrozen=$frozen")

                if (!clocked || frozen) {
                    Log.d(TAG, "⚠️ [OT TICK] No longer clocked in / frozen — stopping service")
                    stopSelf()
                    return
                }

                // Run network call off the main thread
                Thread { fetchAndEvaluate() }.start()

                if (!isServiceDestroyed) handler.postDelayed(this, FETCH_INTERVAL_MS)
            }
        }
        handler.post(fetchRunnable!!)
    }

    // ════════════════════════════════════════════════════════════════════════
    // FETCH + EVALUATE  — background thread
    // ════════════════════════════════════════════════════════════════════════

    private fun fetchAndEvaluate() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Re-read dep_id in case it was updated since last fetch
        depId = listOf(KEY_DEP_ID, "flutter.cached_dep_id", "flutter.$KEY_DEP_ID")
            .firstNotNullOfOrNull { prefStr(prefs, it).takeIf { v -> v.isNotEmpty() } } ?: ""

        Log.d(TAG, "🌐 [OT API] ── fetchAndEvaluate() ──────────────────────────────")
        Log.d(TAG, "🌐 [OT API] depId = \"$depId\"")
        Log.d(TAG, "🌐 [OT API] OT clock-in time = $overtimeClockInTime")

        if (depId.isEmpty()) {
            Log.w(TAG, "⚠️ [OT API] dep_id empty — skipping API call. Using cached cap if available.")
            evaluateWithCachedCap(prefs)
            return
        }

        val url = "$OT_API_BASE?dep_id=$depId"
        Log.d(TAG, "🌐 [OT API] Request URL: $url")

        try {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.requestMethod  = "GET"
            conn.setRequestProperty("Accept", "application/json")
            conn.connectTimeout = 10_000
            conn.readTimeout    = 10_000

            val status = conn.responseCode
            Log.d(TAG, "🌐 [OT API] HTTP status: $status")

            if (status != 200) {
                Log.w(TAG, "⚠️ [OT API] Non-200 ($status) — using cached cap")
                conn.disconnect()
                evaluateWithCachedCap(prefs)
                return
            }

            val body = conn.inputStream.bufferedReader().readText().trim()
            conn.disconnect()

            Log.d(TAG, "📦 [OT API] Raw response: $body")

            val capMinutes = parseOtCapFromBody(body)

            if (capMinutes == null || capMinutes <= 0) {
                Log.w(TAG, "⚠️ [OT API] DAILY_OT_CAP not found in response — using cached cap")
                evaluateWithCachedCap(prefs)
                return
            }

            Log.d(TAG, "✅ [OT API] DAILY_OT_CAP = ${capMinutes}min (${capMinutes/60}h ${capMinutes%60}m)")

            // ── Store live API data in SharedPreferences ─────────────────────
            val responseKey = "${KEY_OT_CAP_RESPONSE}_dep_${depId}"
            prefs.edit().apply {
                putString(responseKey,    body)                        // raw JSON
                putInt(KEY_OT_CAP_MINUTES, capMinutes)                 // parsed cap
                putString(KEY_OT_LAST_FETCH, sdfFull.format(Date()))   // last fetch timestamp
                apply()
            }
            Log.d(TAG, "💾 [OT PREFS] Stored → key=\"$responseKey\"  cap=${capMinutes}min  fetchTime=${sdfFull.format(Date())}")

            if (cachedCapMinutes != capMinutes) {
                Log.d(TAG, "📢 [OT API] Cap CHANGED: ${cachedCapMinutes}min → ${capMinutes}min")
            }
            cachedCapMinutes = capMinutes

            // ── Now evaluate remaining time ───────────────────────────────────
            evaluateOtExpiry(prefs, capMinutes)

        } catch (e: Exception) {
            Log.e(TAG, "❌ [OT API] Network/parse error: ${e.message}")
            Log.e(TAG, "❌ [OT API] Falling back to cached cap")
            evaluateWithCachedCap(prefs)
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // EVALUATE EXPIRY
    // ════════════════════════════════════════════════════════════════════════

    /** Network failed → use last stored cap if available */
    private fun evaluateWithCachedCap(prefs: SharedPreferences) {
        val cached = prefs.getInt(KEY_OT_CAP_MINUTES, 0)
        Log.d(TAG, "📋 [OT EVAL] evaluateWithCachedCap → cached cap = ${cached}min")
        if (cached > 0) {
            evaluateOtExpiry(prefs, cached)
        } else {
            Log.w(TAG, "⚠️ [OT EVAL] No cached cap — trying saved OT end time directly")
            evaluateFromSavedEndTime(prefs)
        }
    }

    /** Directly use the pre-saved OT end time (from Dart side) */
    private fun evaluateFromSavedEndTime(prefs: SharedPreferences) {
        val endStr = listOf(KEY_OT_END_TIME, "flutter.$KEY_OT_END_TIME")
            .firstNotNullOfOrNull { prefStr(prefs, it).takeIf { v -> v.isNotEmpty() } } ?: ""
        if (endStr.isEmpty()) {
            Log.w(TAG, "⚠️ [OT EVAL] No saved OT end time — cannot evaluate. Waiting for next tick.")
            return
        }
        val endTime = parseDate(endStr) ?: run {
            Log.e(TAG, "❌ [OT EVAL] Cannot parse saved end time: \"$endStr\"")
            return
        }
        val remainSec = (endTime.time - System.currentTimeMillis()) / 1000
        Log.d(TAG, "⏰ [OT EVAL] Saved end=$endStr  remaining=${remainSec}s")

        if (remainSec <= 0) {
            Log.d(TAG, "🔴 [OT EVAL] Expired via saved end time → CLOCKOUT")
            handler.post { triggerOvertimeClockout() }
        } else {
            val label = formatDuration(remainSec)
            Log.d(TAG, "✅ [OT EVAL] Still active — $label remaining")
            handler.post { updateStatusNotification("⏱️ Overtime: $label remaining") }
        }
    }

    /**
     * Core evaluation: given cap minutes + clock-in time → compute remaining.
     * If <= 0: fire clockout. Otherwise: update notification + reschedule alarm.
     */
    private fun evaluateOtExpiry(prefs: SharedPreferences, capMinutes: Int) {
        // Re-read clock-in time in case it changed (new session after re-clock-in)
        val clockInStr = listOf(KEY_OT_CLOCK_IN_TIME, "flutter.$KEY_OT_CLOCK_IN_TIME")
            .firstNotNullOfOrNull { prefStr(prefs, it).takeIf { v -> v.isNotEmpty() } } ?: ""
        if (clockInStr.isNotEmpty()) {
            val parsed = parseDate(clockInStr)
            if (parsed != null && parsed != overtimeClockInTime) {
                Log.d(TAG, "🔄 [OT EVAL] OT clock-in changed: $overtimeClockInTime → $parsed (new session detected)")
                overtimeClockInTime = parsed
            }
        }

        val clockIn = overtimeClockInTime ?: run {
            Log.w(TAG, "⚠️ [OT EVAL] No clock-in time available — skipping evaluation")
            return
        }

        val endTime   = Date(clockIn.time + capMinutes * 60_000L)
        val nowMs     = System.currentTimeMillis()
        val remainMs  = endTime.time - nowMs
        val remainSec = remainMs / 1000

        Log.d(TAG, "⏰ [OT EVAL] clockIn=$clockIn  cap=${capMinutes}min  endsAt=$endTime  remainingSec=$remainSec")

        // ── Persist end time so Dart side + AlarmManager can both read it ────
        val endIso = sdfFull.format(endTime)
        prefs.edit().apply {
            putString(KEY_OT_END_TIME,            endIso)
            putString("flutter.$KEY_OT_END_TIME",  endIso)
            apply()
        }
        Log.d(TAG, "💾 [OT PREFS] OT end time saved: $endIso")

        if (remainMs <= 0) {
            Log.d(TAG, "")
            Log.d(TAG, "═══════════════════════════════════════════════════════════════")
            Log.d(TAG, "🔴 [OT EVAL] OVERTIME CAP EXPIRED ← remaining=$remainSec s")
            Log.d(TAG, "🔴 [OT EVAL] Triggering auto clockout NOW")
            Log.d(TAG, "═══════════════════════════════════════════════════════════════")
            Log.d(TAG, "")
            handler.post { triggerOvertimeClockout() }
        } else {
            val label = formatDuration(remainSec)
            Log.d(TAG, "✅ [OT EVAL] Overtime ACTIVE — $label remaining  (endsAt=$endIso)")
            handler.post { updateStatusNotification("⏱️ Overtime: $label remaining") }
            // Refresh kill-safe alarm each time cap is re-calculated
            scheduleOtAlarm(endTime.time)
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // CLOCKOUT  — core action
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Writes all clockout keys to SharedPreferences (same pattern as
     * LocationMonitorService.handleCriticalEvent) then stops the service.
     * Flutter reads these on next resume and POSTs attendance.
     * Koi network call Kotlin side se nahi — Flutter POST handle karta hai.
     */
    private fun triggerOvertimeClockout() {
        val prefs      = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alreadyFrz = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        Log.d(TAG, "")
        Log.d(TAG, "══════════════════════════════════════════════════════════════")
        Log.d(TAG, "⏰ [OT CLOCKOUT] triggerOvertimeClockout() CALLED")
        Log.d(TAG, "⏰ [OT CLOCKOUT] alreadyFrozen = $alreadyFrz")
        Log.d(TAG, "══════════════════════════════════════════════════════════════")

        if (alreadyFrz) {
            Log.d(TAG, "⚠️ [OT CLOCKOUT] Timer already frozen — skipping duplicate clockout")
            stopSelf()
            return
        }

        // Cancel the AlarmManager alarm (we are handling it right now)
        cancelOtAlarm()

        val reason    = "System Clockout - On Overtime End"
        val timestamp = sdfFull.format(Date())
        val clockInTime = prefStr(prefs, "flutter.clockInTime")

        val fastJson = """{"fast_attendanceId":"","fast_userId":"$deviceId","fast_clockOutTime":"$timestamp","fast_totalTime":"00:00:00","fast_totalDistance":0.0,"fast_reason":"$reason","fast_clockInTime":"$clockInTime"}"""

        Log.d(TAG, "📝 [OT CLOCKOUT] Writing SharedPreferences clockout data…")
        Log.d(TAG, "   reason     = $reason")
        Log.d(TAG, "   timestamp  = $timestamp")
        Log.d(TAG, "   clockIn    = $clockInTime")
        Log.d(TAG, "   fastJson   = $fastJson")

        try {
            prefs.edit().apply {
                // ── Same keys as LocationMonitorService.handleCriticalEvent() ──
                putBoolean(KEY_HAS_CRITICAL_EVT,              true)
                putBoolean(KEY_IS_TIMER_FROZEN,               true)
                putString(KEY_EVT_TIMESTAMP,                  timestamp)
                putString(KEY_EVT_REASON,                     reason)
                putBoolean(KEY_IS_CLOCKED_IN,                 false)
                putBoolean("flutter.pending_gpx_close",       true)
                putString("flutter.fastClockOutTime",         timestamp)
                putString("flutter.fastClockOutDistance",     "0.0")
                putString("flutter.fastClockOutReason",       reason)
                putBoolean("flutter.hasFastClockOutData",     true)
                putBoolean("flutter.clockOutPending",         true)
                putString("flutter.fastClockOutData",         fastJson)

                // ── OT-specific: mark today so re-clock-in handles next shift ──
                val todayDate = sdfDate.format(Date())
                putString(KEY_OT_DONE_DATE, todayDate)
                Log.d(TAG, "💾 [OT CLOCKOUT] overtime_clockout_done_date saved: $todayDate")

                commit()   // synchronous write (important before stopSelf)
            }
            Log.d(TAG, "✅ [OT CLOCKOUT] SharedPreferences written successfully")
            Log.d(TAG, "✅ [OT CLOCKOUT] Flutter will read flutter.clockOutPending on next resume and POST attendance")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [OT CLOCKOUT] Failed to write SharedPreferences: ${e.message}")
        }

        // ── Show high-priority notification ──────────────────────────────────
        showClockoutNotification(reason, timestamp)

        Log.d(TAG, "")
        Log.d(TAG, "🛑 [OT CLOCKOUT] Stopping OvertimeMonitorService — job done.")
        Log.d(TAG, "")

        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        stopSelf()
    }

    // ════════════════════════════════════════════════════════════════════════
    // ALARM MANAGER  — exact RTC_WAKEUP alarm (survives process kill)
    // ════════════════════════════════════════════════════════════════════════

    private fun scheduleOtAlarm(triggerAtMs: Long) {
        try {
            val intent = Intent(applicationContext, OvertimeMonitorService::class.java).apply {
                putExtra(EXTRA_OT_ALARM_TRIGGER, true)
                putExtra(EXTRA_DEVICE_ID,        deviceId)
                putExtra(EXTRA_COMPANY_CODE,     companyCode)
                putExtra(EXTRA_EMP_NAME,         empName)
            }
            val pi = PendingIntent.getService(
                applicationContext, ALARM_REQ_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms() -> {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                    Log.d(TAG, "⏰ [OT ALARM] setExactAndAllowWhileIdle — fires at ${sdfFull.format(Date(triggerAtMs))}")
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                    Log.d(TAG, "⏰ [OT ALARM] setAndAllowWhileIdle — fires at ${sdfFull.format(Date(triggerAtMs))}")
                }
                else -> {
                    am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
                    Log.d(TAG, "⏰ [OT ALARM] set() — fires at ${sdfFull.format(Date(triggerAtMs))}")
                }
            }
            val diffMin = ((triggerAtMs - System.currentTimeMillis()) / 60_000).toInt()
            Log.d(TAG, "⏰ [OT ALARM] ✅ Kill-safe alarm set → in ${diffMin}min (survives OEM force-kill)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [OT ALARM] scheduleOtAlarm error: ${e.message}")
        }
    }

    private fun cancelOtAlarm() {
        try {
            val intent = Intent(applicationContext, OvertimeMonitorService::class.java).apply {
                putExtra(EXTRA_OT_ALARM_TRIGGER, true)
            }
            val pi = PendingIntent.getService(
                applicationContext, ALARM_REQ_CODE, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                (getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
                pi.cancel()
                Log.d(TAG, "⏰ [OT ALARM] AlarmManager alarm cancelled")
            } else {
                Log.d(TAG, "⏰ [OT ALARM] No pending alarm to cancel")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ [OT ALARM] cancelOtAlarm error: ${e.message}")
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // JSON PARSING
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Parses DAILY_OT_CAP from ORDS response.
     * Response: { "items": [{ "DAILY_OT_CAP": 2 }], ... }
     * DAILY_OT_CAP = hours → returns minutes.
     * Returns null if key not found / parse fails.
     */
    private fun parseOtCapFromBody(body: String): Int? {
        return try {
            val json = JSONObject(body)

            // Helper: try both DAILY_OT_CAP and daily_ot_cap
            fun JSONObject.getCapRaw(): Any? = opt("DAILY_OT_CAP") ?: opt("daily_ot_cap")

            val capRaw: Any? = run {
                val items = json.optJSONArray("items")
                if (items != null && items.length() > 0) {
                    val first = items.getJSONObject(0)
                    first.getCapRaw().also {
                        Log.d(TAG, "📦 [OT PARSE] Found in items[0]: $it")
                    }
                } else {
                    json.getCapRaw().also {
                        Log.d(TAG, "📦 [OT PARSE] Found in flat map: $it")
                    }
                }
            }

            if (capRaw == null) {
                Log.w(TAG, "⚠️ [OT PARSE] DAILY_OT_CAP key NOT found in response")
                return null
            }

            val capHours   = capRaw.toString().toDoubleOrNull() ?: return null
            val capMinutes = (capHours * 60).toInt()

            Log.d(TAG, "✅ [OT PARSE] DAILY_OT_CAP = $capHours hours = $capMinutes minutes")
            if (capMinutes > 0) capMinutes else null
        } catch (e: Exception) {
            Log.e(TAG, "❌ [OT PARSE] parseOtCapFromBody error: ${e.message}")
            null
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // NOTIFICATIONS
    // ════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Ongoing status channel (low priority — stays in shade)
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Overtime Monitor",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Shows remaining overtime time in notification shade"
                }
            )

            // Clockout alert channel (high priority — heads-up + vibration)
            nm.createNotificationChannel(
                NotificationChannel(
                    CLOCKOUT_CHANNEL_ID,
                    "Overtime Auto Clockout Alert",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Shown when overtime cap expires and user is auto-clocked out"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 700, 200, 700, 200, 700)
                    enableLights(true)
                    lightColor = android.graphics.Color.RED
                }
            )
            Log.d(TAG, "🔔 [OT NOTIF] Notification channels created")
        }
    }

    private fun buildStatusNotification(msg: String): Notification {
        val pi = launchPendingIntent(0)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("⏰ Overtime Monitor")
            .setContentText(msg)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pi)
            .build()
    }

    private fun updateStatusNotification(msg: String) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID, buildStatusNotification(msg))
        } catch (_: Exception) {}
    }

    /** High-priority alert shown when overtime actually expires */
    private fun showClockoutNotification(reason: String, timestamp: String) {
        try {
            val pi = launchPendingIntent(99)
            val notif = NotificationCompat.Builder(this, CLOCKOUT_CHANNEL_ID)
                .setContentTitle("⏰ Overtime Ended — Auto Clock Out")
                .setContentText("Your overtime has expired. Open app to confirm.")
                .setStyle(
                    NotificationCompat.BigTextStyle().bigText(
                        "Your overtime session has ended and you have been automatically " +
                                "clocked out.\n\nOpen the app to post your attendance record."
                    )
                )
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(pi)
                .setVibrate(longArrayOf(0, 700, 200, 700, 200, 700))
                .setLights(android.graphics.Color.RED, 1000, 500)
                .build()
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(CLOCKOUT_NOTIF_ID, notif)
            Log.d(TAG, "🔔 [OT NOTIF] Clockout notification shown — $reason @ $timestamp")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [OT NOTIF] showClockoutNotification error: ${e.message}")
        }
    }

    private fun launchPendingIntent(reqCode: Int): PendingIntent {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            this, reqCode, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    // ════════════════════════════════════════════════════════════════════════
    // WAKELOCK
    // ════════════════════════════════════════════════════════════════════════

    private fun acquireWakeLock() {
        try {
            val pm   = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GPS_Workforce_Monitor:OtMonitorLock"
            )
            wakeLock?.acquire()
            Log.d(TAG, "✅ [OT] PARTIAL_WAKE_LOCK acquired")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ [OT] WakeLock acquire failed: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
            Log.d(TAG, "✅ [OT] WakeLock released")
        } catch (_: Exception) {}
    }

    // ════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ════════════════════════════════════════════════════════════════════════

    /** Safely read a SharedPreferences key regardless of stored type */
    private fun prefStr(prefs: SharedPreferences, key: String): String {
        return try {
            val raw = prefs.all[key] ?: return ""
            val str = raw.toString().trim()
            if (str == "null") "" else str
        } catch (_: Exception) { "" }
    }

    /** Try multiple ISO-8601 formats */
    private fun parseDate(raw: String): Date? {
        return try {
            sdfFull.parse(raw)
        } catch (_: Exception) {
            try { sdfFull2.parse(raw) } catch (_: Exception) { null }
        }
    }

    /** Formats seconds → "Xh YYm ZZs" or "YYm ZZs" */
    private fun formatDuration(totalSeconds: Long): String {
        val h = totalSeconds / 3600
        val m = (totalSeconds % 3600) / 60
        val s = totalSeconds % 60
        return if (h > 0) String.format("%dh %02dm %02ds", h, m, s)
        else       String.format("%dm %02ds", m, s)
    }

    private fun logBlock(msg: String) {
        Log.d(TAG, "")
        Log.d(TAG, "═══════════════════════════════════════════════════════════════")
        Log.d(TAG, "⏰ [OT] $msg")
        Log.d(TAG, "═══════════════════════════════════════════════════════════════")
        Log.d(TAG, "")
    }
}