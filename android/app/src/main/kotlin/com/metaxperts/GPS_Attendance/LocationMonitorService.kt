
package com.metaxperts.GPS_Workforce_Monitor

import android.app.AppOpsManager
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import android.Manifest

import org.eclipse.paho.client.mqttv3.IMqttActionListener
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken
import org.eclipse.paho.client.mqttv3.IMqttToken
import org.eclipse.paho.client.mqttv3.MqttAsyncClient
import org.eclipse.paho.client.mqttv3.MqttCallback
import org.eclipse.paho.client.mqttv3.MqttConnectOptions
import org.eclipse.paho.client.mqttv3.MqttMessage
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence

import org.json.JSONArray
import org.json.JSONObject

import java.io.File
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

import android.os.BatteryManager
import android.location.Geocoder
import java.util.Locale as JavaLocale

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LocationMonitorService : Service() {
    private val CHANNEL_ID           = "location_monitor_channel"
    private val URGENT_CHANNEL_ID    = "urgent_auto_clockout_channel"
    private val SHIFT_END_CHANNEL_ID = "shift_end_alarm_channel_v2" // ✅ v2 = fresh channel with USAGE_ALARM attrs (bypasses Flutter channel that lacks alarm AudioAttributes)
    private val BREAK_END_CHANNEL_ID = "break_end_notification_channel" // ✅ Break end notification channel
    private val NOTIFICATION_ID      = 1001
    private val BREAK_END_NOTIF_ID   = 2001 // ✅ Break end notification ID
    private val CHECK_INTERVAL    = 2000L
    private val GPS_PUBLISH_MS    = 5000L

    private val HTTP_POST_MS  = 3 * 60 * 1000L
    private val HTTP_POST_URL = "http://oracle.metaxperts.net/ords/gps_workforce/emplocation/post/"

    // ✅ FIX #1: Increased capture interval from 1s → 10s to reduce polyline noise
    private val BULK_CAPTURE_MS = 10_000L   // was 1_000L
    private val BULK_POST_MS    = 30_000L   // was 10_000L — less network spam
    //    private val BULK_POST_URL   = "http://103.149.33.102:8001/location/bulk"
    private val BULK_POST_URL   = "http://119.153.102.7:8001/location/bulk"

    // ✅ FIX #3: Filters to prevent noisy/duplicate GPS points
    private val MIN_ACCURACY_METERS  = 50f    // skip if GPS accuracy worse than 50m
    private val MIN_DISTANCE_METERS  = 10f    // skip if moved less than 10m from last point

    // ✅ FIX #5: Offline persistence file name
    private val OFFLINE_BUFFER_FILE = "bulk_location_offline.json"

    //    private val MQTT_HOST = "103.149.33.102"
    private val MQTT_HOST = "119.153.102.7"
    private val MQTT_PORT = 1883

    private val mqttTopic get() = "gps/$companyCode/$deviceId"

    private val PREFS_NAME             = "FlutterSharedPreferences"
    private val KEY_IS_CLOCKED_IN      = "flutter.isClockedIn"
    private val KEY_HAS_CRITICAL_EVENT = "flutter.has_critical_event_pending"
    private val KEY_EVENT_TIMESTAMP    = "flutter.critical_event_timestamp"
    private val KEY_EVENT_REASON       = "flutter.critical_event_reason"
    private val KEY_IS_TIMER_FROZEN    = "flutter.is_timer_frozen"
    private val KEY_ELAPSED_TIME       = "flutter.elapsed_time"

    private lateinit var handler: Handler
    private var checkRunnable: Runnable     = Runnable {}
    private var gpsRunnable: Runnable       = Runnable {}
    private var httpPostRunnable: Runnable? = null
    private var watchdogRunnable: Runnable? = null
    private var heartbeatRunnable: Runnable? = null
    private var bulkCaptureRunnable: Runnable? = null
    private var bulkPostRunnable: Runnable? = null
    private var isDestroyed = false

    private var wakeLock: android.os.PowerManager.WakeLock? = null
    // ✅ FIX: Class-level reference so onDestroy() can unregisterReceiver()
    private var locationModeReceiver: android.content.BroadcastReceiver? = null

    private var wasLocationEnabled   = true
    private var wasPermissionGranted = true
    private var isClockedIn          = false
    private var lastEventTime: Long  = 0
    private var lastEventReason: String = ""
    private var serviceStartTime: Date  = Date()

    private var lastLat      = 0.0
    private var lastLon      = 0.0
    private var lastAccuracy = 0f
    private var lastSpeed    = 0f
    private var lastHeartbeatTime: Long = 0
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null

    // ✅ FIX #3: Track last bulk-posted position for minimum distance check
    private var prevBulkLat = 0.0
    private var prevBulkLng = 0.0

    // ✅ Break end notification — track which break end time we already notified for
    private var lastBreakEndNotifiedTime = ""

    private var mqttClient: MqttAsyncClient? = null
    private var isMqttConnected = false
    private var isConnecting    = false
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private var appOpsManager: AppOpsManager? = null
    private var appOpsCallback: AppOpsManager.OnOpChangedListener? = null

    private var deviceId    = ""
    private var companyCode = ""
    private var empName     = ""
    private var depId       = ""
    private var empImage    = ""

    private val bulkLocationBuffer = mutableListOf<JSONObject>()

    private val FAKE_GPS_API         = "http://oracle.metaxperts.net/ords/gps_workforce/fakegps/post/"
    private var lastFakeGpsReportTime: Long = 0
    private val FAKE_GPS_COOLDOWN_MS = 30_000L

    companion object {
        const val EXTRA_DEVICE_ID          = "deviceId"
        const val EXTRA_COMPANY_CODE       = "companyCode"
        const val EXTRA_EMP_NAME           = "empName"
        // ✅ BACKGROUND ALARM FIX: intent extra for AlarmManager-triggered shift-end clockout
        const val EXTRA_SHIFT_END_TRIGGER  = "shift_end_trigger"
        private const val SHIFT_END_ALARM_REQ = 77   // AlarmManager request code

        fun start(context: Context) {
            try {
                val i = Intent(context, LocationMonitorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (e: Exception) {
                android.util.Log.e("LocationMonitor", "start: ${e.message}")
            }
        }

        fun start(context: Context, deviceId: String, companyCode: String, empName: String) {
            try {
                val i = Intent(context, LocationMonitorService::class.java).apply {
                    putExtra(EXTRA_DEVICE_ID,    deviceId)
                    putExtra(EXTRA_COMPANY_CODE, companyCode)
                    putExtra(EXTRA_EMP_NAME,     empName)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (e: Exception) {
                android.util.Log.e("LocationMonitor", "start(identity): ${e.message}")
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, LocationMonitorService::class.java))
            } catch (e: Exception) {
                android.util.Log.e("LocationMonitor", "stop: ${e.message}")
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ✅ FIX #4: OFFLINE BUFFER PERSISTENCE
    // Saves in-memory buffer to disk so it survives service kill
    // ══════════════════════════════════════════════════════════════════════════

    private fun saveOfflineBuffer(records: List<JSONObject>) {
        if (records.isEmpty()) return
        try {
            val file  = File(filesDir, OFFLINE_BUFFER_FILE)
            val array = JSONArray()
            records.forEach { array.put(it) }
            file.writeText(array.toString())
            android.util.Log.d("LocationMonitor",
                "💾 [BULK OFFLINE] Saved ${records.size} records to disk → $OFFLINE_BUFFER_FILE")
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "❌ [BULK OFFLINE] saveOfflineBuffer error: ${e.message}")
        }
    }

    /**
     * Loads previously-saved offline records from disk and DELETES the file.
     * Called at the start of every postBulkLocationToApi() so stale records
     * are included in the next successful API call.
     */
    private fun loadAndClearOfflineBuffer(): List<JSONObject> {
        val result = mutableListOf<JSONObject>()
        try {
            val file = File(filesDir, OFFLINE_BUFFER_FILE)
            if (!file.exists()) return result
            val content = file.readText().trim()
            if (content.isEmpty()) { file.delete(); return result }
            val array = JSONArray(content)
            for (i in 0 until array.length()) {
                result.add(array.getJSONObject(i))
            }
            file.delete()   // Clear file after loading — prevents re-posting
            android.util.Log.d("LocationMonitor",
                "📂 [BULK OFFLINE] Loaded ${result.size} saved records from disk")
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "❌ [BULK OFFLINE] loadOfflineBuffer error: ${e.message}")
        }
        return result
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════

    private fun parseTimeTo24h(raw: String): Pair<Int, Int>? {
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
            Pair(hour, minute)
        } catch (e: Exception) {
            null
        }
    }

    private fun prefString(prefs: android.content.SharedPreferences, key: String): String {
        return try {
            val raw = prefs.all[key] ?: return ""
            val str = raw.toString().trim()
            if (str == "null") "" else str
        } catch (e: Exception) {
            ""
        }
    }

    private fun firstNonEmptyPref(prefs: android.content.SharedPreferences, keys: List<String>): String {
        for (key in keys) {
            val value = prefString(prefs, key).trim()
            if (value.isNotEmpty()) return value
        }
        return ""
    }

    // ══════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════

    override fun onCreate() {
        super.onCreate()
        handler = Handler(Looper.getMainLooper())

        try {
            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            wakeLock = pm.newWakeLock(
                android.os.PowerManager.PARTIAL_WAKE_LOCK,
                "GPS_Workforce_Monitor:MqttBgLock"
            )
            wakeLock?.acquire()
            android.util.Log.d("LocationMonitor", "✅ PARTIAL_WAKE_LOCK acquired")
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "WakeLock acquire failed: ${e.message}")
        }

        registerReceivers()
        registerNetworkCallback()
        registerAppOpsListener()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        serviceStartTime = Date()

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        deviceId    = intent?.getStringExtra(EXTRA_DEVICE_ID)?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "user_name")
        companyCode = intent?.getStringExtra(EXTRA_COMPANY_CODE)?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "company_code")
        empName     = intent?.getStringExtra(EXTRA_EMP_NAME)?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "emp_name")

        depId    = prefString(prefs, "flutter.cached_dep_id")
        empImage = prefString(prefs, "flutter.cached_image_url")

        prefs.edit().apply {
            if (deviceId.isNotEmpty())    putString("user_name",    deviceId)
            if (companyCode.isNotEmpty()) putString("company_code", companyCode)
            if (empName.isNotEmpty())     putString("emp_name",     empName)
            apply()
        }

        android.util.Log.d("LocationMonitor",
            "identity → deviceId=$deviceId  company=$companyCode  emp=$empName  topic=$mqttTopic")
        android.util.Log.d("LocationMonitor",
            "⚙️ [CONFIG] BULK_CAPTURE=${BULK_CAPTURE_MS}ms  BULK_POST=${BULK_POST_MS}ms  " +
                    "MIN_ACCURACY=${MIN_ACCURACY_METERS}m  MIN_DISTANCE=${MIN_DISTANCE_METERS}m")

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID, buildNotification("Initialising..."),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification("Initialising..."))
            }
        } catch (e: Exception) {
            android.util.Log.d("LocationMonitor", "startForeground failed: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        // ✅ BACKGROUND ALARM FIX: Service was started by AlarmManager at exact shift-end time
        val isShiftEndTrigger = intent?.getBooleanExtra(EXTRA_SHIFT_END_TRIGGER, false) ?: false
        if (isShiftEndTrigger) {
            android.util.Log.d("LocationMonitor", "⏰ [SHIFT END ALARM] Triggered by AlarmManager — firing clockout")
            val clk = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
            val frz = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

            // ✅ FIX: Overtime user — agar re-clock-in ke baad alarm fire hua to ignore karo.
            // shift_end_clockout_done_date aaj ki date hai matlab shift-end clockout ho chuka tha,
            // phir user ne dobara clock-in kiya — yeh overtime session hai, alarm fire nahi hona chahiye.
            val overtime = prefString(prefs, "flutter.cached_overtime").lowercase()
            val isOvertimeUser = overtime == "yes" || overtime == "y" || overtime == "true" || overtime == "1"
            if (isOvertimeUser) {
                val savedDate = prefString(prefs, "flutter.shift_end_clockout_done_date")
                val todayDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                if (savedDate == todayDate) {
                    android.util.Log.d("LocationMonitor",
                        "⏰ [SHIFT END ALARM] Overtime re-clock-in detected — alarm ignored (shift_end_clockout_done_date=today)")
                    stopSelf()
                    return START_NOT_STICKY
                }
            }

            if (clk && !frz) {
                handler.postDelayed({ handleCriticalEvent("System Clockout - Shift End") }, 300)
            } else {
                android.util.Log.d("LocationMonitor", "⏰ [SHIFT END ALARM] Already clocked out — ignoring")
                stopSelf()
            }
            return START_NOT_STICKY
        }

        wasLocationEnabled   = isLocationEnabled()
        wasPermissionGranted = checkLocationPermission()

        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clockedIn && !isFrozen) {
            if (!wasPermissionGranted) {
                handler.postDelayed({ handleCriticalEvent("System Clockout - Permission Revoked") }, 500)
                return START_STICKY
            }
            if (!wasLocationEnabled) {
                handler.postDelayed({ handleCriticalEvent("System Clockout - Location Off") }, 500)
                return START_STICKY
            }
            startLocationUpdates()
            connectMqtt()
            // ✅ BACKGROUND ALARM FIX: Schedule exact AlarmManager alarm at shift end time
            scheduleShiftEndAlarm()
//            IntervalSelfieAlarmReceiver.scheduleAll(applicationContext)
        }

        startMonitoring()
        return START_STICKY
    }

    private fun startMonitoring() {
        checkRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                checkLocationAndPermission()
                handler.postDelayed(this, CHECK_INTERVAL)
            }
        }
        handler.post(checkRunnable)

        gpsRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                if (isClockedIn && isMqttConnected && (lastLat != 0.0 || lastLon != 0.0)) {
                    publishLocationViaMqtt()
                }
                handler.postDelayed(this, GPS_PUBLISH_MS)
            }
        }
        handler.postDelayed(gpsRunnable, GPS_PUBLISH_MS)

        httpPostRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed || !isClockedIn) return
                try {
                    val p       = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val clocked = p.getBoolean(KEY_IS_CLOCKED_IN, false)
                    val frozen  = p.getBoolean(KEY_IS_TIMER_FROZEN, false)
                    if (clocked && !frozen && isNetworkAvailable()) {
                        postLocationToApi()
                    }
                    if (!isDestroyed) handler.postDelayed(this, HTTP_POST_MS)
                } catch (e: Exception) {
                    if (!isDestroyed && isClockedIn) handler.postDelayed(this, HTTP_POST_MS)
                }
            }
        }.also {
            if (!isDestroyed) handler.postDelayed(it, HTTP_POST_MS)
        }

        // ✅ FIX #1: BULK_CAPTURE_MS is now 10 seconds (was 1s)
        bulkCaptureRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                val p = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clocked = p.getBoolean(KEY_IS_CLOCKED_IN, false)
                val frozen  = p.getBoolean(KEY_IS_TIMER_FROZEN, false)
                if (clocked && !frozen) {
                    captureBulkLocationSnapshot()
                }
                if (!isDestroyed) handler.postDelayed(this, BULK_CAPTURE_MS)
            }
        }
        handler.postDelayed(bulkCaptureRunnable!!, BULK_CAPTURE_MS)

        // ✅ FIX #1: BULK_POST_MS is now 30 seconds (was 10s)
        bulkPostRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                val p = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clocked = p.getBoolean(KEY_IS_CLOCKED_IN, false)
                if (clocked && isNetworkAvailable()) {
                    postBulkLocationToApi()
                }
                if (!isDestroyed) handler.postDelayed(this, BULK_POST_MS)
            }
        }
        handler.postDelayed(bulkPostRunnable!!, BULK_POST_MS)

        startMqttWatchdog()
        startHeartbeatWatchdog()
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ✅ BULK CAPTURE — FIXED VERSION
    //    Fix #2: Accuracy filter (skip if GPS > 50m accuracy)
    //    Fix #3: Minimum distance filter (skip if moved < 10m)
    //    Fix: Comprehensive debug logs for every decision
    // ══════════════════════════════════════════════════════════════════════════
    private fun captureBulkLocationSnapshot() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            var lat = if (lastLat != 0.0) lastLat else 0.0
            var lng = if (lastLon != 0.0) lastLon else 0.0
            var accuracy = lastAccuracy

            // Fallback to last known location if live location not yet received
            if (lat == 0.0 && lng == 0.0) {
                try {
                    val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                        listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER).forEach { provider ->
                            if (lat != 0.0 || lng != 0.0) return@forEach
                            val loc = lm.getLastKnownLocation(provider)
                            if (loc != null) {
                                lat      = loc.latitude
                                lng      = loc.longitude
                                accuracy = loc.accuracy
                                android.util.Log.d("LocationMonitor",
                                    "📡 [BULK] Using lastKnownLocation from $provider: lat=$lat lng=$lng acc=${accuracy}m")
                            }
                        }
                    }
                } catch (_: Exception) {}
            }

            // ✅ FIX: Skip if still no valid coordinates
            if (lat == 0.0 && lng == 0.0) {
                android.util.Log.w("LocationMonitor", "⚠️ [BULK] SKIP — lat/lng are 0.0, no valid GPS fix yet")
                return
            }

            // ✅ FIX #2: Accuracy filter — skip poor GPS readings
            if (accuracy > MIN_ACCURACY_METERS && accuracy != 0f) {
                android.util.Log.w("LocationMonitor",
                    "⚠️ [BULK] SKIP — poor GPS accuracy: ${accuracy}m (threshold: ${MIN_ACCURACY_METERS}m)")
                return
            }

            // ✅ FIX #3: Minimum distance filter — skip if not moved enough
            if (prevBulkLat != 0.0 && prevBulkLng != 0.0) {
                val distanceResults = FloatArray(1)
                Location.distanceBetween(prevBulkLat, prevBulkLng, lat, lng, distanceResults)
                val movedMeters = distanceResults[0]
                if (movedMeters < MIN_DISTANCE_METERS) {
                    android.util.Log.d("LocationMonitor",
                        "⏭️ [BULK] SKIP — moved only ${movedMeters.toInt()}m " +
                                "(min: ${MIN_DISTANCE_METERS.toInt()}m) — avoiding stationary noise")
                    return
                }
                android.util.Log.d("LocationMonitor",
                    "📏 [BULK] Distance from last point: ${movedMeters.toInt()}m — adding point")
            }

            // Update previous position
            prevBulkLat = lat
            prevBulkLng = lng

            val userId = firstNonEmptyPref(prefs, listOf("flutter.user_id", "user_id", "flutter.emp_id", "emp_id"))
                .ifEmpty { deviceId }

            val bookerName = firstNonEmptyPref(prefs, listOf("flutter.booker_name", "booker_name", "flutter.emp_name", "emp_name"))
                .ifEmpty { empName }

            val designation = firstNonEmptyPref(prefs, listOf(
                "flutter.cached_designation",
                "flutter.userDesignation",
                "userDesignation",
                "designation",
                "flutter.designation",
                "job",
                "role"
            )).ifEmpty { "GPS" }

            val company = firstNonEmptyPref(prefs, listOf("flutter.company_code", "company_code"))
                .ifEmpty { companyCode }

            // ✅ FIX: Validate required fields before recording
            if (userId.isEmpty()) {
                android.util.Log.w("LocationMonitor", "⚠️ [BULK] SKIP — user_id is empty")
                return
            }

            val now  = Date()
            val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(now)
            val timeStr = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(now)
            val locationTrackingId = "KT-${userId}-${now.time}"  // KT prefix = Kotlin source

            val snap = JSONObject().apply {
                put("locationtracking_id", locationTrackingId)
                put("locationtracking_date", dateStr)
                put("locationtracking_time", timeStr)
                put("user_id", userId)
                put("lat_in", lat)
                put("lng_in", lng)
                put("booker_name", bookerName)
                put("designation", designation)
                put("posted", false)
                put("company_code", company)
            }

            synchronized(bulkLocationBuffer) {
                bulkLocationBuffer.add(snap)
                android.util.Log.d("LocationMonitor",
                    "✅ [BULK] Buffered #${bulkLocationBuffer.size} | " +
                            "user=$userId lat=$lat lng=$lng acc=${accuracy}m " +
                            "date=$dateStr time=$timeStr")
            }

        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "❌ [BULK] captureBulkLocationSnapshot error: ${e.message}")
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ✅ BULK POST — FIXED VERSION
    //    Fix #4: Load offline saved records from disk and merge before posting
    //    Fix: Save to file on failure so no data is lost
    //    Fix: Comprehensive request/response logging
    // ══════════════════════════════════════════════════════════════════════════
    private fun postBulkLocationToApi() {
        try {
            // Take current in-memory snapshot
            val inMemorySnapshot = synchronized(bulkLocationBuffer) {
                if (bulkLocationBuffer.isEmpty()) {
                    // Still check disk for any saved offline records
                    val fromDisk = loadAndClearOfflineBuffer()
                    if (fromDisk.isEmpty()) {
                        android.util.Log.d("LocationMonitor", "ℹ️ [BULK] Nothing to post — buffer and disk both empty")
                        return
                    }
                    return@synchronized fromDisk
                }
                val copy = bulkLocationBuffer.toList()
                bulkLocationBuffer.clear()
                copy
            }

            // ✅ FIX #4: Merge with any records saved offline on previous failure/kill
            val offlineRecords = loadAndClearOfflineBuffer()
            val allRecords     = offlineRecords + inMemorySnapshot

            if (allRecords.isEmpty()) return

            android.util.Log.d("LocationMonitor",
                "📤 [BULK] Sending ${allRecords.size} records " +
                        "(disk: ${offlineRecords.size}, buffer: ${inMemorySnapshot.size}) → $BULK_POST_URL")

            Thread {
                var success = false
                try {
                    val jsonArray = JSONArray()
                    allRecords.forEach { jsonArray.put(it) }
                    val rootObj = JSONObject().apply { put("records", jsonArray) }
                    val body    = rootObj.toString()

                    android.util.Log.d("LocationMonitor",
                        "📡 [BULK] REQUEST body (first record): ${allRecords.firstOrNull()}")

                    val conn = (URL(BULK_POST_URL).openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("Accept", "application/json")
                        doOutput        = true
                        connectTimeout  = 15000
                        readTimeout     = 15000
                    }

                    OutputStreamWriter(conn.outputStream).use { it.write(body) }
                    val responseCode = conn.responseCode
                    val responseMsg  = try { conn.responseMessage } catch (_: Exception) { "" }
                    conn.disconnect()

                    android.util.Log.d("LocationMonitor",
                        "📥 [BULK] RESPONSE code=$responseCode msg=$responseMsg " +
                                "records_sent=${allRecords.size}")

                    if (responseCode in 200..299) {
                        success = true
                        android.util.Log.d("LocationMonitor",
                            "✅ [BULK] Successfully synced ${allRecords.size} records to server")
                    } else {
                        android.util.Log.w("LocationMonitor",
                            "⚠️ [BULK] API returned $responseCode — saving ${allRecords.size} records to disk")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("LocationMonitor",
                        "❌ [BULK] Network error: ${e.message} — saving ${allRecords.size} records to disk")
                }

                // ✅ FIX #4: On any failure, persist records to disk so they survive kill
                if (!success) {
                    saveOfflineBuffer(allRecords)
                }
            }.start()

        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "❌ [BULK] postBulkLocationToApi error: ${e.message}")
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MQTT + WATCHDOGS (unchanged)
    // ══════════════════════════════════════════════════════════════════════════

    private fun startMqttWatchdog() {
        var consecutiveFailures = 0
        watchdogRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                val frozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
                if (clocked && !frozen) {
                    if (!isMqttConnected && !isConnecting && isNetworkAvailable()) {
                        consecutiveFailures++
                        android.util.Log.d("LocationMonitor",
                            "🔁 [WATCHDOG] MQTT not connected — Attempt #$consecutiveFailures")
                        connectMqtt()
                    } else if (isMqttConnected) {
                        consecutiveFailures = 0
                    }
                } else {
                    consecutiveFailures = 0
                }
                if (!isDestroyed) handler.postDelayed(this, 15_000L)
            }
        }
        handler.postDelayed(watchdogRunnable!!, 15_000L)
    }

    private fun startHeartbeatWatchdog() {
        heartbeatRunnable = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                val frozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
                if (clocked && !frozen) {
                    val now = System.currentTimeMillis()
                    if (now - lastHeartbeatTime > 12_000L) {
                        lastHeartbeatTime = now
                        if (isMqttConnected && (lastLat != 0.0 || lastLon != 0.0)) {
                            publishLocationViaMqtt()
                        }
                    }
                }
                if (!isDestroyed) handler.postDelayed(this, 5_000L)
            }
        }
        handler.postDelayed(heartbeatRunnable!!, 5_000L)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CRITICAL EVENT / CLOCKOUT DETECTION (unchanged)
    // ══════════════════════════════════════════════════════════════════════════

    private fun checkLocationAndPermission() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)

        // ✅ Break end check — isClockedIn se PEHLE karo
        // Wajah: break start hone pe user clock-out ho jata hai (isClockedIn=false)
        // Isliye agar check baad mein hota to kabhi fire nahi hota
        checkBreakEndNotification(prefs)

        if (!isClockedIn) {
            updateNotification("Not clocked in", false)
            return
        }

        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
        if (isFrozen) {
            handler.removeCallbacks(checkRunnable)
            return
        }

        val calendar = java.util.Calendar.getInstance()
        val hour   = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val minute = calendar.get(java.util.Calendar.MINUTE)

        if (hour == 23 && minute == 58) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 60000) {
                lastEventTime   = currentTime
                lastEventReason = "System Clockout - Midnight Time"
                handleCriticalEvent("System Clockout - Midnight Time")
                return
            }
        }

        val cachedEndTime = prefString(prefs, "flutter.cached_end_time")
        if (cachedEndTime.isNotEmpty()) {
            try {
                val parsed = parseTimeTo24h(cachedEndTime)
                if (parsed != null) {
                    val endTotalMin = parsed.first * 60 + parsed.second
                    val nowTotalMin = hour * 60 + minute
                    val diffMin     = nowTotalMin - endTotalMin
                    if (diffMin in 0..480) {
                        // ✅ FIX: Overtime user — agar aaj ka shift-end clockout already ho chuka hai
                        // (re-clock-in ke baad wala case) to dobara auto-clockout mat karo.
                        val overtime = prefString(prefs, "flutter.cached_overtime").lowercase()
                        val isOvertimeUser = overtime == "yes" || overtime == "y" || overtime == "true" || overtime == "1"
                        if (isOvertimeUser) {
                            val savedDate = prefString(prefs, "flutter.shift_end_clockout_done_date")
                            val todayDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                            if (savedDate == todayDate) {
                                android.util.Log.d("LocationMonitor",
                                    "⏰ [SHIFT END] Overtime user — clockout already done today — skipping (re-clock-in protected)")
                                return
                            }
                        }
                        val currentTime = System.currentTimeMillis()
                        if (currentTime - lastEventTime > 60000 && lastEventReason != "System Clockout - Shift End") {
                            lastEventTime   = currentTime
                            lastEventReason = "System Clockout - Shift End"
                            handleCriticalEvent("System Clockout - Shift End")
                            return
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        val currentLocationEnabled   = isLocationEnabled()
        val currentPermissionGranted = checkLocationPermission()

        if (wasPermissionGranted && !currentPermissionGranted) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 5000 && lastEventReason != "System Clockout - Permission Revoked") {
                lastEventTime   = currentTime
                lastEventReason = "System Clockout - Permission Revoked"
                handleCriticalEvent("System Clockout - Permission Revoked")
                return
            }
        }

        if (wasLocationEnabled && !currentLocationEnabled) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 5000 && lastEventReason != "System Clockout - Location Off") {
                lastEventTime   = currentTime
                lastEventReason = "System Clockout - Location Off"
                handleCriticalEvent("System Clockout - Location Off")
                return
            }
        }

        wasLocationEnabled   = currentLocationEnabled
        wasPermissionGranted = currentPermissionGranted

        val status = if (currentLocationEnabled && currentPermissionGranted) {
            "Monitoring | MQTT: ${if (isMqttConnected) "●" else "○"} | Buf:${bulkLocationBuffer.size}"
        } else {
            "Issue detected - Processing..."
        }
        updateNotification(status, false)
    }

    private fun handleCriticalEvent(reason: String) {
        val prefs         = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alreadyFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
        if (alreadyFrozen) return

        // ✅ BACKGROUND ALARM FIX: Cancel any pending shift-end AlarmManager alarm
        cancelShiftEndAlarm()
        IntervalSelfieAlarmReceiver.cancelAll(applicationContext)

        val editor    = prefs.edit()
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())

        editor.putBoolean(KEY_HAS_CRITICAL_EVENT, true)
        editor.putBoolean(KEY_IS_TIMER_FROZEN, true)
        editor.putString(KEY_EVENT_TIMESTAMP, timestamp)
        editor.putString(KEY_EVENT_REASON, reason)
        editor.putBoolean(KEY_IS_CLOCKED_IN, false)
        editor.putBoolean("flutter.pending_gpx_close", true)
        editor.putString("flutter.fastClockOutTime", timestamp)
        editor.putString("flutter.fastClockOutDistance", "0.0")
        editor.putString("flutter.fastClockOutReason", reason)
        editor.putBoolean("flutter.hasFastClockOutData", true)
        editor.putBoolean("flutter.clockOutPending", true)

        // ✅ FIX: Shift-end clockout hone pe aaj ki date save karo — overtime users ke liye
        // re-clock-in ke baad dobara auto-clockout nahi hoga.
        if (reason == "System Clockout - Shift End") {
            val todayDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            editor.putString("flutter.shift_end_clockout_done_date", todayDate)
            android.util.Log.d("LocationMonitor",
                "⏰ [SHIFT END] shift_end_clockout_done_date saved: $todayDate")
        }

        val clockInTime = prefs.getString("flutter.clockInTime", "") ?: ""
        val fastJson = """{"fast_attendanceId":"","fast_userId":"","fast_clockOutTime":"$timestamp","fast_totalTime":"00:00:00","fast_totalDistance":0.0,"fast_reason":"$reason","fast_clockInTime":"$clockInTime"}"""
        editor.putString("flutter.fastClockOutData", fastJson)

        val isTravelMode = prefs.getBoolean("flutter.is_travel_mode", false)
        if (isTravelMode) {
            val travelId       = prefs.getString("flutter.travel_id", "") ?: ""
            val travelStartStr = prefs.getString("flutter.travel_start_time", "") ?: ""
            val travelDist     = try {
                prefs.getString("flutter.travel_distance", "0.0")?.toDoubleOrNull() ?: 0.0
            } catch (_: Exception) { 0.0 }

            var travelElapsed = "00:00:00"
            try {
                if (travelStartStr.isNotEmpty()) {
                    val sdf   = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                    val start = sdf.parse(travelStartStr)
                    if (start != null) {
                        val elapsedSec = ((Date().time - start.time) / 1000).toInt()
                        val h = elapsedSec / 3600
                        val m = (elapsedSec % 3600) / 60
                        val s = elapsedSec % 60
                        travelElapsed = String.format("%02d:%02d:%02d", h, m, s)
                    }
                }
            } catch (_: Exception) {}

            val travelFastJson = """{"travel_attendanceId":"$travelId","travel_clockOutTime":"$timestamp","travel_totalTime":"$travelElapsed","travel_totalDistance":$travelDist,"travel_reason":"$reason","travel_clockInTime":"$travelStartStr"}"""
            editor.putBoolean("flutter.hasTravelFastClockOut", true)
            editor.putString("flutter.travelFastClockOutData", travelFastJson)
            editor.putString("flutter.travelFastClockOutTime", timestamp)
            editor.putString("flutter.travelFastClockOutReason", reason)
            editor.putString("flutter.travelFastClockOutId", travelId)
            editor.putBoolean("flutter.is_travel_mode", false)

            android.util.Log.d("LocationMonitor",
                "🚗 [TRAVEL] Auto clockout during travel → id=$travelId reason=$reason dist=$travelDist")
        }

        try { editor.commit() } catch (e: Exception) { editor.apply() }

        showCriticalNotification(reason, timestamp)
        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)

        // ✅ NEW: Shift end pe selfie notification — foreground, background, aur app-killed teeno cases
        if (reason == "System Clockout - Shift End") {
            android.util.Log.d("LocationMonitor", "📸 [SELFIE NOTIF] Shift ended — sending selfie reminder notification")
            showSelfieReminderNotification()
            // Grace time ke baad bhi remind karo — SharedPrefs se policy padhte hain
            scheduleSelfieGraceNotifications(prefs)
        }

        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        httpPostRunnable?.let { handler.removeCallbacks(it) }
        watchdogRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        bulkCaptureRunnable?.let { handler.removeCallbacks(it) }
        bulkPostRunnable?.let { handler.removeCallbacks(it) }

        // ✅ FIX: Flush + persist remaining bulk buffer before stopping
        val remaining = synchronized(bulkLocationBuffer) {
            if (bulkLocationBuffer.isNotEmpty()) {
                val copy = bulkLocationBuffer.toList()
                bulkLocationBuffer.clear()
                copy
            } else emptyList()
        }
        if (remaining.isNotEmpty()) {
            if (isNetworkAvailable()) {
                postBulkLocationToApi()
            } else {
                saveOfflineBuffer(remaining)
                android.util.Log.d("LocationMonitor",
                    "💾 [BULK] Saved ${remaining.size} records offline (critical event, no network)")
            }
        }

        disconnectMqtt()
        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        stopSelf()
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ✅ BREAK END NOTIFICATION
    // Foreground, background, aur app killed — teeno cases mein kaam karta hai.
    // Flutter har 10 sec mein latest break schedule SharedPreferences mein save
    // karta hai (flutter.break_scheduled_end). Yeh function har 2 sec mein us
    // latest value ko read karke check karta hai — koi other logic change nahi.
    // ══════════════════════════════════════════════════════════════════════════

    private fun checkBreakEndNotification(prefs: android.content.SharedPreferences) {
        try {
            val breakEndStr = prefString(prefs, "flutter.break_scheduled_end")
            if (breakEndStr.isEmpty()) return
            if (breakEndStr == lastBreakEndNotifiedTime) return

            val parsed = parseTimeTo24h(breakEndStr) ?: return
            val cal    = java.util.Calendar.getInstance()
            val nowMins = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + cal.get(java.util.Calendar.MINUTE)
            val endMins = parsed.first * 60 + parsed.second
            val diff    = nowMins - endMins  // positive = past break end

            // Fire within 0-5 minute window after break end
            if (diff in 0..5) {
                lastBreakEndNotifiedTime = breakEndStr
                showBreakEndNotification(breakEndStr)
                android.util.Log.d("LocationMonitor",
                    "⏰ [BREAK END] Notification sent — breakEnd=$breakEndStr diff=${diff}min")
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor",
                "❌ [BREAK END] checkBreakEndNotification error: ${e.message}")
        }
    }

    private fun showBreakEndNotification(breakEndTime: String) {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val notification = NotificationCompat.Builder(this, BREAK_END_CHANNEL_ID)
                .setContentTitle("⏰ Break Time Over")
                .setContentText("Your break has ended — please return to work!")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 500, 200, 500))
                .setLights(android.graphics.Color.YELLOW, 1000, 500)
                .build()
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(BREAK_END_NOTIF_ID, notification)
            android.util.Log.d("LocationMonitor",
                "🔔 [BREAK END] Notification shown for end time: $breakEndTime")
            // ── POST notification log to API (offline-safe) ───────────────
            NotificationApiLogger.log(this, "⏰ Break Time Over")
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor",
                "❌ [BREAK END] showBreakEndNotification error: ${e.message}")
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ✅ NEW: SELFIE REMINDER NOTIFICATION
    // Shift end ke baad "Your shift has ended. Please take your selfie." notification
    // Foreground, background, aur app-killed — teeno cases mein kaam karta hai.
    // Immediate notification yahan se show hoti hai (Kotlin — app-killed bhi cover hota hai).
    // Grace window ke baad notifications Flutter ka zonedSchedule handle karta hai.
    // ══════════════════════════════════════════════════════════════════════════

    private val SELFIE_CHANNEL_ID  = "selfie_grace_notif_channel"   // Flutter wala hi channel
    private val SELFIE_NOTIF_BASE  = 8100   // base notification ID — avoids collision

    private fun showSelfieReminderNotification() {
        try {
            // Ensure channel exists (Flutter wala channel reuse karte hain — same ID)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    SELFIE_CHANNEL_ID,
                    "Selfie Grace Notifications",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description      = "Reminders to take attendance selfie after shift end"
                    enableVibration(true)
                    enableLights(true)
                    lightColor       = android.graphics.Color.CYAN
                }
                (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this, SELFIE_NOTIF_BASE, launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val notification = NotificationCompat.Builder(this, SELFIE_CHANNEL_ID)
                .setContentTitle("Attendance Selfie")
                .setContentText("Your shift has ended. Please take your selfie.")
                .setStyle(NotificationCompat.BigTextStyle()
                    .bigText("Your shift has ended. Please take your selfie."))
                .setSmallIcon(android.R.drawable.ic_menu_camera)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 500, 200, 500))
                .build()

            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(SELFIE_NOTIF_BASE, notification)

            android.util.Log.d("LocationMonitor",
                "📸 [SELFIE NOTIF] Immediate selfie reminder shown at ${SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())}")
            // ── POST notification log to API (offline-safe) ───────────────
            NotificationApiLogger.log(this, "Attendance Selfie")
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "❌ [SELFIE NOTIF] showSelfieReminderNotification error: ${e.message}")
        }
    }

    /// Logs policy ke baad further notifications — Flutter ka zonedSchedule cover karta hai grace window
    private fun scheduleSelfieGraceNotifications(prefs: android.content.SharedPreferences) {
        val notifCount   = prefs.getInt("flutter.selfie_policy_notif_count", 0)
        val graceMinutes = prefs.getInt("flutter.selfie_policy_grace_min",  0)
        android.util.Log.d("LocationMonitor",
            "📸 [SELFIE NOTIF] Policy → notifCount=$notifCount  graceMin=$graceMinutes — " +
                    "grace-window notifications will be handled by Flutter zonedSchedule on next app open")
    }

    // ══════════════════════════════════════════════════════════════════════════
    // LOCATION UPDATES (unchanged)
    // ══════════════════════════════════════════════════════════════════════════

    private fun startLocationUpdates() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) return

        try {
            if (locationListener != null) return
            locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

            locationListener = object : LocationListener {
                override fun onLocationChanged(loc: Location) {
                    lastLat      = loc.latitude
                    lastLon      = loc.longitude
                    lastAccuracy = loc.accuracy
                    lastSpeed    = loc.speed
                    lastHeartbeatTime = System.currentTimeMillis()
                    android.util.Log.d("LocationMonitor",
                        "📍 [GPS] lat=$lastLat lng=$lastLon acc=${lastAccuracy}m spd=${lastSpeed}")
                    if (loc.isFromMockProvider) checkAndReportFakeGps(loc)
                }
                @Deprecated("Deprecated")
                override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
                override fun onProviderEnabled(p: String) {}
                override fun onProviderDisabled(p: String) {}
            }

            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).forEach { p ->
                try {
                    if (locationManager?.isProviderEnabled(p) == true) {
                        locationManager?.requestLocationUpdates(
                            p, 1000L, 0f, locationListener!!, Looper.getMainLooper()
                        )
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    private fun stopLocationUpdates() {
        try { locationListener?.let { locationManager?.removeUpdates(it) } } catch (_: Exception) {}
        locationListener = null
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MQTT (unchanged)
    // ══════════════════════════════════════════════════════════════════════════

    private fun connectMqtt() {
        if (isMqttConnected || isConnecting || !isNetworkAvailable()) return
        isConnecting = true

        handler.postDelayed({
            if (isConnecting && !isMqttConnected && !isDestroyed) {
                isConnecting = false
                safeCloseClient()
            }
        }, 15_000L)

        try {
            val clientId = "android_bg_${System.currentTimeMillis()}"
            android.util.Log.d("LocationMonitor",
                "Connecting tcp://$MQTT_HOST:$MQTT_PORT id=$clientId topic=$mqttTopic")

            safeCloseClient()

            mqttClient = MqttAsyncClient(
                "tcp://$MQTT_HOST:$MQTT_PORT", clientId, MemoryPersistence()
            )

            mqttClient?.setCallback(object : MqttCallback {
                override fun connectionLost(cause: Throwable?) {
                    isMqttConnected = false
                    isConnecting    = false
                    android.util.Log.d("LocationMonitor", "Connection lost: ${cause?.message}")
                }
                override fun messageArrived(topic: String?, message: MqttMessage?) {}
                override fun deliveryComplete(token: IMqttDeliveryToken?) {}
            })

            val opts = MqttConnectOptions().apply {
                isCleanSession       = true
                keepAliveInterval    = 30
                connectionTimeout    = 15
                isAutomaticReconnect = false
            }

            mqttClient?.connect(opts, null, object : IMqttActionListener {
                override fun onSuccess(asyncActionToken: IMqttToken?) {
                    isMqttConnected   = true
                    isConnecting      = false
                    lastHeartbeatTime = System.currentTimeMillis()
                    android.util.Log.d("LocationMonitor", "✅ MQTT Connected! topic=$mqttTopic")
                    updateNotification("Online | GPS → $mqttTopic", false)
                }
                override fun onFailure(asyncActionToken: IMqttToken?, exception: Throwable?) {
                    isMqttConnected = false
                    isConnecting    = false
                    android.util.Log.d("LocationMonitor", "Connect failed: ${exception?.message}")
                }
            })
        } catch (e: Exception) {
            isMqttConnected = false
            isConnecting    = false
        }
    }

    private fun publishLocationViaMqtt() {
        if (!isMqttConnected || (lastLat == 0.0 && lastLon == 0.0)) return
        try {
            val payload = buildPayload()
            val msg     = MqttMessage(payload.toByteArray(Charsets.UTF_8))
            msg.qos     = 1
            mqttClient?.publish(mqttTopic, msg)
            lastHeartbeatTime = System.currentTimeMillis()
        } catch (e: Exception) {
            isMqttConnected = false
        }
    }

    private fun buildPayload(): String {
        val ts = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).format(Date())
        return JSONObject().apply {
            put("device_id",    deviceId)
            put("company_code", companyCode)
            put("emp_name",     empName)
            put("dept_id",      depId)
            put("emp_image",    empImage)
            put("track_id",     System.currentTimeMillis())
            put("lat",          lastLat)
            put("lon",          lastLon)
            put("accuracy",     lastAccuracy.toDouble())
            put("speed",        lastSpeed.toDouble())
            put("timestamp",    ts)
            put("source",       "android_background_service")
        }.toString()
    }

    private fun postLocationToApi() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val empIdKeys = listOf(
                "flutter.emp_id", "emp_id", "flutter.empId", "empId",
                "flutter.user_id", "user_id", "flutter.userId", "userId"
            )
            var empId = ""
            for (key in empIdKeys) {
                val value = prefString(prefs, key)
                if (value.isNotEmpty()) { empId = value; break }
            }
            if (empId.isEmpty()) {
                try {
                    for ((key, raw) in prefs.all) {
                        if (key.contains("emp_id", true) || key.contains("empId", true) ||
                            key.contains("user_id", true) || key.contains("userId", true)) {
                            val candidate = raw?.toString()?.trim() ?: ""
                            if (candidate.isNotEmpty() && candidate != "null") {
                                empId = candidate; break
                            }
                        }
                    }
                } catch (_: Exception) {}
            }
            if (empId.isEmpty()) return

            var lat = lastLat; var lon = lastLon
            if (lat == 0.0 && lon == 0.0) {
                try {
                    val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                            val loc = lm.getLastKnownLocation(p)
                            if (loc != null) { lat = loc.latitude; lon = loc.longitude; break }
                        }
                    }
                } catch (_: Exception) {}
            }
            if (lat == 0.0 && lon == 0.0) return

            val name    = empName.ifEmpty { prefString(prefs, "flutter.emp_name").ifEmpty { prefString(prefs, "emp_name") } }
            val company = companyCode.ifEmpty { prefString(prefs, "flutter.company_code").ifEmpty { prefString(prefs, "company_code") } }

            val snapLat = lat; val snapLon = lon
            val snapEmp = empId; val snapName = name; val snapCo = company

            Thread {
                try {
                    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val battery = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).coerceIn(0, 100)

                    var address = ""
                    try {
                        @Suppress("DEPRECATION")
                        val results = Geocoder(applicationContext, JavaLocale.getDefault()).getFromLocation(snapLat, snapLon, 1)
                        if (!results.isNullOrEmpty()) {
                            val a = results[0]
                            address = listOfNotNull(a.thoroughfare, a.subLocality, a.locality, a.adminArea, a.countryName)
                                .filter { it.isNotEmpty() }.joinToString(", ")
                        }
                    } catch (_: Exception) {}

                    val trackDate = SimpleDateFormat("dd-MM-yyyy HH:mm:ss", Locale.getDefault()).format(Date())
                    val json = JSONObject().apply {
                        put("lat", snapLat); put("lng", snapLon); put("emp_id", snapEmp)
                        put("emp_name", snapName); put("company_code", snapCo)
                        put("track_date", trackDate); put("battery_percent", battery); put("address", address)
                    }.toString()

                    val conn = (URL(HTTP_POST_URL).openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("Accept", "application/json")
                        doOutput = true; connectTimeout = 15000; readTimeout = 15000
                    }
                    OutputStreamWriter(conn.outputStream).use { it.write(json) }
                    conn.responseCode
                    conn.disconnect()
                } catch (_: Exception) {}
            }.start()
        } catch (_: Exception) {}
    }

    private fun checkAndReportFakeGps(loc: Location) {
        val now = System.currentTimeMillis()
        if (now - lastFakeGpsReportTime < FAKE_GPS_COOLDOWN_MS) return
        lastFakeGpsReportTime = now

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val empId = prefString(prefs, "emp_id")
        val detectedAt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())
        val json = JSONObject().apply {
            put("emp_id", empId); put("emp_name", empName); put("company_code", companyCode)
            put("latitude", loc.latitude); put("longitude", loc.longitude); put("detected_at", detectedAt)
        }.toString()

        Thread {
            try {
                val conn = (URL(FAKE_GPS_API).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"; setRequestProperty("Content-Type", "application/json")
                    doOutput = true; connectTimeout = 10_000; readTimeout = 10_000
                }
                OutputStreamWriter(conn.outputStream).use { it.write(json) }
                conn.responseCode; conn.disconnect()
            } catch (_: Exception) {}
        }.start()
    }

    private fun disconnectMqtt() {
        try { if (mqttClient?.isConnected == true) mqttClient?.disconnect() } catch (_: Exception) {}
        isMqttConnected = false
        safeCloseClient()
    }

    private fun safeCloseClient() {
        try { mqttClient?.close() } catch (_: Exception) {}
        mqttClient = null
    }

    private fun isNetworkAvailable(): Boolean {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val nw = cm.activeNetwork ?: return false
        val nc = cm.getNetworkCapabilities(nw) ?: return false
        return nc.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun registerNetworkCallback() {
        try {
            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    android.util.Log.d("LocationMonitor", "✅ Network available — reconnecting MQTT + flushing offline buffer")
                    handler.post {
                        if (!isMqttConnected && !isConnecting && !isDestroyed) {
                            connectMqtt()
                        }
                        // ✅ FIX: Trigger bulk post when internet comes back
                        if (!isDestroyed) {
                            postBulkLocationToApi()
                        }
                    }
                }
                override fun onLost(network: Network) {
                    isMqttConnected = false
                    isConnecting = false
                    android.util.Log.d("LocationMonitor", "📴 Network lost — future bulk points will be saved to disk")
                }
            }
            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
        } catch (_: Exception) {}
    }

    private fun unregisterNetworkCallback() {
        try { networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) } } catch (_: Exception) {}
        networkCallback = null
    }

    private fun registerAppOpsListener() {
        try {
            appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val listener = AppOpsManager.OnOpChangedListener { _, pkg ->
                if (pkg == packageName) handler.post { checkLocationAndPermission() }
            }
            appOpsManager?.startWatchingMode(AppOpsManager.OPSTR_FINE_LOCATION, packageName, listener)
            appOpsCallback = listener
        } catch (_: Exception) {}
    }

    private fun unregisterAppOpsListener() {
        try { appOpsCallback?.let { appOpsManager?.stopWatchingMode(it) }; appOpsCallback = null } catch (_: Exception) {}
    }

    private fun registerReceivers() {
        // ✅ FIX: Wrapped in try-catch — Android 14+ (API 34) requires RECEIVER_EXPORTED for
        // system broadcasts. Without this, the service crashes in onCreate() and ALL background
        // work stops (no alarms, no auto-clockout detection, no critical event on reopen).
        try {
            locationModeReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == LocationManager.MODE_CHANGED_ACTION) {
                        handler.post { checkLocationAndPermission() }
                    }
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Android 14+: system broadcasts require RECEIVER_EXPORTED flag
                registerReceiver(
                    locationModeReceiver,
                    IntentFilter(LocationManager.MODE_CHANGED_ACTION),
                    Context.RECEIVER_EXPORTED
                )
            } else {
                registerReceiver(locationModeReceiver, IntentFilter(LocationManager.MODE_CHANGED_ACTION))
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "registerReceivers error: ${e.message}")
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NOTIFICATIONS (unchanged)
    // ══════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(CHANNEL_ID, "Location Monitor Service", NotificationManager.IMPORTANCE_LOW)
                .apply { description = "Monitors location + MQTT GPS publishing" }
            val urgentChannel = NotificationChannel(URGENT_CHANNEL_ID, "URGENT Auto Clockout", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "Critical auto clockout notifications"; enableVibration(true); enableLights(true); lightColor = android.graphics.Color.RED }

            // ✅ NEW: Dedicated Shift End channel — device alarm sound + max vibration
            // ✅ FIX: getDefaultUri can return null on devices with no alarm sound set;
            // null URI causes setSound(null,...) → silent channel → no alarm in background
            val alarmSoundUri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE)
                ?: android.net.Uri.parse("content://settings/system/alarm_alert")
            val alarmAudioAttr = android.media.AudioAttributes.Builder()
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                .build()
            val shiftEndChannel = NotificationChannel(SHIFT_END_CHANNEL_ID, "Shift End Alarm", NotificationManager.IMPORTANCE_HIGH)
                .apply {
                    description = "Full device alarm for shift end auto clockout"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 1000, 200, 1000, 200, 1000)
                    setSound(alarmSoundUri, alarmAudioAttr)
                    enableLights(true)
                    lightColor = android.graphics.Color.RED
                }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
            manager.createNotificationChannel(urgentChannel)
            manager.createNotificationChannel(shiftEndChannel)    // ✅ NEW channel registered

            // ✅ Break end notification channel
            val breakEndChannel = NotificationChannel(BREAK_END_CHANNEL_ID, "Break Notifications", NotificationManager.IMPORTANCE_HIGH)
                .apply {
                    description = "Notifies when your scheduled break time is over"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                    enableLights(true)
                }
            manager.createNotificationChannel(breakEndChannel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Attendance Active").setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent).setOngoing(true).setSilent(true).build()
    }

    private fun updateNotification(text: String, isAlert: Boolean) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(if (isAlert) "⚠️ ATTENTION REQUIRED" else "Attendance Active")
            .setContentText(text).setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent).setOngoing(true).setSilent(!isAlert)
            .apply { if (isAlert) { setColor(android.graphics.Color.RED); setLights(android.graphics.Color.RED, 1000, 500) } }
            .build()
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }

    private fun showCriticalNotification(reason: String, time: String) {
        // ✅ NEW: Shift End uses dedicated alarm channel; all others use urgent channel
        val isShiftEnd = (reason == "System Clockout - Shift End")
        val channelId  = if (isShiftEnd) SHIFT_END_CHANNEL_ID else URGENT_CHANNEL_ID

        val title = when (reason) {
            "System Clockout - Location Off"       -> "⚠️ LOCATION TURNED OFF"
            "System Clockout - Permission Revoked" -> "⚠️ PERMISSION REVOKED"
            "System Clockout - Midnight Time"      -> "⚠️ MIDNIGHT AUTO CLOCKOUT"
            "System Clockout - Shift End"          -> "⏰ SHIFT END AUTO CLOCKOUT"
            else                                   -> "⚠️ AUTO CLOCKOUT"
        }
        val message = "Time: $time\nApp was closed - Event captured. Open app to sync."
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title).setContentText(message).setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX).setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true).setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 1000, 500, 1000)).setLights(android.graphics.Color.RED, 1000, 500)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(9999, notification)

        // ── POST notification log to API (offline-safe) ───────────────────
        NotificationApiLogger.log(this, title)

        // ✅ NEW: Shift End — vibrate at MAX amplitude for exactly 60 seconds
        if (isShiftEnd) {
            triggerShiftEndVibration()
        }
    }

    // ✅ NEW: Vibrates the device at maximum intensity for 60 full seconds on shift-end clockout
    private fun triggerShiftEndVibration() {
        try {
            val vibrator: android.os.Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Max amplitude (255) for a single 60-second burst — no repeat
                val effect = android.os.VibrationEffect.createOneShot(60_000L, 255)
                vibrator.vibrate(effect)
            } else {
                // Pre-API 26 fallback — vibrate for 60 seconds
                @Suppress("DEPRECATION")
                vibrator.vibrate(60_000L)
            }
            android.util.Log.d("LocationMonitor", "📳 [SHIFT END] Max vibration started for 60 seconds")
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "❌ [SHIFT END] Vibration error: ${e.message}")
        }
    }

    private fun isLocationEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            (getSystemService(Context.LOCATION_SERVICE) as LocationManager).isLocationEnabled
        } else {
            try {
                Settings.Secure.getInt(contentResolver, Settings.Secure.LOCATION_MODE, Settings.Secure.LOCATION_MODE_OFF) != Settings.Secure.LOCATION_MODE_OFF
            } catch (_: Exception) { false }
        }
    }

    private fun checkLocationPermission(): Boolean {
        return try {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) { false }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        val prefs   = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val frozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        // ✅ FIX: Save buffer to disk before task is removed
        val snapshot = synchronized(bulkLocationBuffer) {
            if (bulkLocationBuffer.isNotEmpty()) {
                val copy = bulkLocationBuffer.toList()
                bulkLocationBuffer.clear()
                copy
            } else emptyList()
        }
        if (snapshot.isNotEmpty()) {
            saveOfflineBuffer(snapshot)
            android.util.Log.d("LocationMonitor",
                "💾 [BULK] onTaskRemoved — persisted ${snapshot.size} records to disk")
        }

        if (clocked && !frozen) {
            // ✅ BACKGROUND ALARM FIX: Check shift end time
            // ✅ FIX: Overtime re-clock-in check — agar aaj shift-end clockout ho chuka aur dobara clock-in hua
            // to background kill pe bhi alarm schedule mat karo.
            val overtime = prefString(prefs, "flutter.cached_overtime").lowercase()
            val isOvertimeUser = overtime == "yes" || overtime == "y" || overtime == "true" || overtime == "1"
            val overtimeDoneToday = if (isOvertimeUser) {
                val savedDate = prefString(prefs, "flutter.shift_end_clockout_done_date")
                val todayDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                savedDate == todayDate
            } else false

            val endTimeStr = prefString(prefs, "flutter.cached_end_time")

            if (endTimeStr.isNotEmpty()) {
                val parsed = parseTimeTo24h(endTimeStr)
                if (parsed != null) {
                    val cal    = java.util.Calendar.getInstance()
                    val nowMin = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + cal.get(java.util.Calendar.MINUTE)
                    val endMin = parsed.first * 60 + parsed.second
                    val diff   = nowMin - endMin

                    if (diff in 0..480) {
                        // ✅ FIX: Overtime re-clock-in — shift-end already hua aaj, dobara clockout mat karo
                        if (overtimeDoneToday) {
                            android.util.Log.d("LocationMonitor",
                                "⏰ [SHIFT END] onTaskRemoved: overtime re-clock-in — skipping clockout (shift_end_clockout_done_date=today)")
                        } else {
                            // Shift end already passed while app was running — clockout NOW before service dies
                            android.util.Log.d("LocationMonitor",
                                "⏰ [SHIFT END] onTaskRemoved: shift end passed ${diff}min ago — clockout now")
                            handleCriticalEvent("System Clockout - Shift End")
                            return   // handleCriticalEvent calls stopSelf()
                        }
                    } else if (diff < 0) {
                        // ✅ FIX: Overtime re-clock-in — alarm schedule mat karo, cancel karo
                        if (overtimeDoneToday) {
                            cancelShiftEndAlarm()
                            android.util.Log.d("LocationMonitor",
                                "⏰ [SHIFT END] onTaskRemoved: overtime re-clock-in — alarm CANCELLED (not scheduled)")
                        } else {
                            // Shift end is in the future — schedule exact AlarmManager wakeup
                            scheduleShiftEndAlarm()
                            android.util.Log.d("LocationMonitor",
                                "⏰ [SHIFT END] onTaskRemoved: shift end in ${-diff}min — alarm scheduled")
                        }
                    }
                }
            }

            val restartIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
                putExtra(EXTRA_DEVICE_ID,    deviceId)
                putExtra(EXTRA_COMPANY_CODE, companyCode)
                putExtra(EXTRA_EMP_NAME,     empName)
            }
            val pi = PendingIntent.getService(applicationContext, 1, restartIntent, PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE)
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerTime  = android.os.SystemClock.elapsedRealtime() + 1000L

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi)
            } else {
                alarmManager.set(AlarmManager.ELAPSED_REALTIME, triggerTime, pi)
            }
            android.util.Log.d("LocationMonitor", "🔄 [RESTART] Service restart scheduled in 1s")
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ✅ BACKGROUND ALARM FIX — SHIFT END EXACT ALARM
    // scheduleShiftEndAlarm(): reads cached_end_time → schedules AlarmManager.RTC_WAKEUP
    //   at the exact wall-clock shift-end time.  This wakeup fires even if the
    //   process is fully dead (bypasses all OEM process killers).
    // cancelShiftEndAlarm(): cancels the PendingIntent when clockout happens normally.
    // ══════════════════════════════════════════════════════════════════════════

    private fun scheduleShiftEndAlarm() {
        try {
            val prefs      = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val endTimeStr = prefString(prefs, "flutter.cached_end_time")
            if (endTimeStr.isEmpty()) {
                android.util.Log.d("LocationMonitor", "⏰ [SHIFT ALARM] No cached_end_time — skipping")
                return
            }
            // ✅ FIX: Overtime user — aaj clockout already ho chuka hai → alarm schedule mat karo
            val overtime = prefString(prefs, "flutter.cached_overtime").lowercase()
            val isOvertimeUser = overtime == "yes" || overtime == "y" || overtime == "true" || overtime == "1"
            if (isOvertimeUser) {
                val savedDate = prefString(prefs, "flutter.shift_end_clockout_done_date")
                val todayDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                if (savedDate == todayDate) {
                    // ✅ FIX: Sirf return nahi — already-set alarm bhi cancel karo.
                    // Warna purana AlarmManager alarm fire ho ke notification + vibration
                    // trigger kar deta hai overtime re-clock-in ke baad.
                    cancelShiftEndAlarm()
                    android.util.Log.d("LocationMonitor",
                        "⏰ [SHIFT ALARM] Overtime user — clockout already done today — alarm CANCELLED (re-clock-in protected)")
                    return
                }
            }

            val parsed = parseTimeTo24h(endTimeStr) ?: run {
                android.util.Log.w("LocationMonitor", "⏰ [SHIFT ALARM] Cannot parse end_time: \"$endTimeStr\"")
                return
            }

            // Build wall-clock trigger time for today
            val cal = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, parsed.first)
                set(java.util.Calendar.MINUTE,      parsed.second)
                set(java.util.Calendar.SECOND,      0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            val triggerMs = cal.timeInMillis
            val nowMs     = System.currentTimeMillis()

            // If the shift end time has already passed today, do not schedule.
            // onTaskRemoved and checkLocationAndPermission cover that path.
            if (triggerMs <= nowMs) {
                android.util.Log.d("LocationMonitor",
                    "⏰ [SHIFT ALARM] Shift end already passed — no new alarm scheduled")
                return
            }

            val shiftIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
                putExtra(EXTRA_SHIFT_END_TRIGGER, true)
                putExtra(EXTRA_DEVICE_ID,         deviceId)
                putExtra(EXTRA_COMPANY_CODE,      companyCode)
                putExtra(EXTRA_EMP_NAME,          empName)
            }
            val pi = PendingIntent.getService(
                applicationContext,
                SHIFT_END_ALARM_REQ,
                shiftIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms() ->
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
                else ->
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerMs, pi)
            }

            val diffMin = ((triggerMs - nowMs) / 60_000).toInt()
            android.util.Log.d("LocationMonitor",
                "⏰ [SHIFT ALARM] ✅ Exact alarm set for $endTimeStr (in ${diffMin}min) — " +
                        "survives process kill on all OEM ROMs")
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "❌ [SHIFT ALARM] scheduleShiftEndAlarm error: ${e.message}")
        }
    }

    private fun cancelShiftEndAlarm() {
        try {
            val shiftIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
                putExtra(EXTRA_SHIFT_END_TRIGGER, true)
            }
            val pi = PendingIntent.getService(
                applicationContext,
                SHIFT_END_ALARM_REQ,
                shiftIntent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                (getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
                pi.cancel()
                android.util.Log.d("LocationMonitor", "⏰ [SHIFT ALARM] Cancelled pending shift-end alarm")
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "❌ [SHIFT ALARM] cancelShiftEndAlarm error: ${e.message}")
        }
    }

    override fun onDestroy() {
        isDestroyed = true
        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        httpPostRunnable?.let { handler.removeCallbacks(it) }
        watchdogRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        bulkCaptureRunnable?.let { handler.removeCallbacks(it) }
        bulkPostRunnable?.let { handler.removeCallbacks(it) }

        // ✅ FIX: Persist remaining buffer to disk on destroy
        val remaining = synchronized(bulkLocationBuffer) {
            if (bulkLocationBuffer.isNotEmpty()) {
                val copy = bulkLocationBuffer.toList()
                bulkLocationBuffer.clear()
                copy
            } else emptyList()
        }

        if (remaining.isNotEmpty()) {
            if (isNetworkAvailable()) {
                // Try online sync first
                postBulkLocationToApi()
            } else {
                // Save to disk for next launch
                saveOfflineBuffer(remaining)
                android.util.Log.d("LocationMonitor",
                    "💾 [BULK] onDestroy — persisted ${remaining.size} records to disk (offline)")
            }
        }

        // Permission-revoked auto clockout check
        try {
            val prefs   = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
            val frozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
            val permNow = checkLocationPermission()

            // ✅ FIX: Always schedule shift-end alarm on destroy so OEM force-kills
            // (which skip onTaskRemoved) still leave a wakeup for the exact shift end time.
            // ✅ FIX: Overtime re-clock-in — agar aaj ka shift-end ho chuka hai to alarm cancel karo.
            if (clocked && !frozen) {
                val otStr = prefString(prefs, "flutter.cached_overtime").lowercase()
                val isOtUser = otStr == "yes" || otStr == "y" || otStr == "true" || otStr == "1"
                val overtimeDoneToday = if (isOtUser) {
                    val savedDate = prefString(prefs, "flutter.shift_end_clockout_done_date")
                    val todayDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                    savedDate == todayDate
                } else false

                if (overtimeDoneToday) {
                    cancelShiftEndAlarm()
                    android.util.Log.d("LocationMonitor",
                        "⏰ [SHIFT ALARM] onDestroy: overtime re-clock-in — alarm CANCELLED")
                } else {
                    scheduleShiftEndAlarm()
                    android.util.Log.d("LocationMonitor",
                        "⏰ [SHIFT ALARM] onDestroy: alarm (re)scheduled to survive process kill")
                }
            }

            if (clocked && !frozen && !permNow) {
                handleCriticalEvent("System Clockout - Permission Revoked")
                android.util.Log.d("LocationMonitor",
                    "onDestroy: permission revoked while clocked-in → auto clockout saved")
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "onDestroy permission-check error: ${e.message}")
        }

        stopLocationUpdates()
        disconnectMqtt()
        unregisterNetworkCallback()
        unregisterAppOpsListener()

        // ✅ FIX: Unregister locationModeReceiver to prevent IntentReceiverLeaked
        try {
            locationModeReceiver?.let { unregisterReceiver(it) }
            locationModeReceiver = null
            android.util.Log.d("LocationMonitor", "✅ locationModeReceiver unregistered")
        } catch (e: Exception) {
            android.util.Log.w("LocationMonitor", "unregisterReceiver warning: ${e.message}")
        }

        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}

        super.onDestroy()
    }
}