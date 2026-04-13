// ============================================================
//  LocationMonitorService.kt — MERGED: Location Monitoring + MQTT + HTTP POST
//
//  ✅ FIX 1: java.lang.Long cannot be cast to java.lang.String
//    Root cause: Flutter stores emp_id as Long in SharedPreferences.
//    prefs.getString() on a Long key throws ClassCastException.
//    Fix: All SharedPreferences reads now use prefs.all[key]?.toString()
//         which safely handles String, Long, Int, Float, Boolean.
//
//  ✅ FIX 2: MQTT not working on release APK / some devices in background
//    - keepAliveInterval reduced 60→20s (OEM devices kill 60s idle TCP)
//    - connectionTimeout increased 10→15s (gives slow networks more time)
//    - 15s safety timeout resets stuck isConnecting flag (OEM may never
//      fire onFailure, leaving isConnecting=true forever → never retries)
//    - MQTT watchdog every 30s detects silent disconnections and reconnects
//    - Exception in connectMqtt() now schedules a retry instead of giving up
// ============================================================

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

// ✅ MQTT Imports
import org.eclipse.paho.client.mqttv3.IMqttActionListener
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken
import org.eclipse.paho.client.mqttv3.IMqttToken
import org.eclipse.paho.client.mqttv3.MqttAsyncClient
import org.eclipse.paho.client.mqttv3.MqttCallback
import org.eclipse.paho.client.mqttv3.MqttConnectOptions
import org.eclipse.paho.client.mqttv3.MqttMessage
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence

// ✅ JSON Import
import org.json.JSONObject

// ✅ HTTP
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

// ✅ Battery + Reverse Geocoding
import android.os.BatteryManager
import android.location.Geocoder
import java.util.Locale as JavaLocale

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LocationMonitorService : Service() {
    private val CHANNEL_ID        = "location_monitor_channel"
    private val URGENT_CHANNEL_ID = "urgent_auto_clockout_channel"
    private val NOTIFICATION_ID   = 1001
    private val CHECK_INTERVAL    = 2000L
    private val GPS_PUBLISH_MS    = 5000L

    // ✅ Background HTTP POST — every 2 minutes
    private val HTTP_POST_MS  = 2 * 60 * 1000L
    private val HTTP_POST_URL = "http://oracle.metaxperts.net/ords/gps_workforce/emplocation/post/"

    // MQTT broker
    private val MQTT_HOST = "103.149.33.102"
    private val MQTT_PORT = 1883

    // Dynamic topic: gps/{companyCode}/{deviceId}
    private val mqttTopic get() = "gps/$companyCode/$deviceId"

    // SharedPreferences keys
    private val PREFS_NAME             = "FlutterSharedPreferences"
    private val KEY_IS_CLOCKED_IN      = "flutter.isClockedIn"
    private val KEY_HAS_CRITICAL_EVENT = "flutter.has_critical_event_pending"
    private val KEY_EVENT_TIMESTAMP    = "flutter.critical_event_timestamp"
    private val KEY_EVENT_REASON       = "flutter.critical_event_reason"
    private val KEY_IS_TIMER_FROZEN    = "flutter.is_timer_frozen"
    private val KEY_ELAPSED_TIME       = "flutter.elapsed_time"

    private lateinit var handler: Handler
    private var checkRunnable: Runnable    = Runnable {}
    private var gpsRunnable: Runnable      = Runnable {}
    private var httpPostRunnable: Runnable? = null
    private var isDestroyed = false

    // ✅ FIX: WakeLock — keeps CPU alive so MQTT TCP socket survives screen-off.
    //         WAKE_LOCK permission is already declared in the manifest.
    //         Without this, the CPU sleeps mid-publish and kills the MQTT socket.
    //         HTTP POST works without it because each POST is a short burst;
    //         MQTT needs the socket open continuously, so it needs this lock.
    private var wakeLock: android.os.PowerManager.WakeLock? = null

    private var wasLocationEnabled   = true
    private var wasPermissionGranted = true
    private var isClockedIn          = false
    private var lastEventTime: Long  = 0
    private var lastEventReason: String = ""
    private var serviceStartTime: Date  = Date()

    // Location
    private var lastLat      = 0.0
    private var lastLon      = 0.0
    private var lastAccuracy = 0f
    private var lastSpeed    = 0f
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null

    // MQTT
    private var mqttClient: MqttAsyncClient? = null
    private var isMqttConnected = false
    private var isConnecting    = false
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // AppOps
    private var appOpsManager: AppOpsManager? = null
    private var appOpsCallback: AppOpsManager.OnOpChangedListener? = null

    // Identity
    private var deviceId    = ""
    private var companyCode = ""
    private var empName     = ""

    // Fake GPS detection
    private val FAKE_GPS_API         = "http://oracle.metaxperts.net/ords/gps_workforce/fakegps/post/"
    private var lastFakeGpsReportTime: Long = 0
    private val FAKE_GPS_COOLDOWN_MS = 30_000L

    companion object {
        const val EXTRA_DEVICE_ID    = "deviceId"
        const val EXTRA_COMPANY_CODE = "companyCode"
        const val EXTRA_EMP_NAME     = "empName"

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

    // =========================================================
    //  SAFE PREF HELPER
    //  ✅ FIX: Reads ANY stored type (String, Long, Int, Float,
    //  Boolean) and returns it as String. This prevents
    //  "java.lang.Long cannot be cast to java.lang.String"
    //  which occurs when Flutter saves emp_id as a Long.
    // =========================================================
    private fun prefString(prefs: android.content.SharedPreferences, key: String): String {
        return try {
            val raw = prefs.all[key] ?: return ""
            val str = raw.toString().trim()
            if (str == "null") "" else str
        } catch (e: Exception) {
            ""
        }
    }

    override fun onCreate() {
        super.onCreate()
        handler = Handler(Looper.getMainLooper())

        // ✅ FIX: Acquire PARTIAL_WAKE_LOCK so the CPU stays awake and the MQTT
        //         TCP socket is not killed when the screen turns off.
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            wakeLock = pm.newWakeLock(
                android.os.PowerManager.PARTIAL_WAKE_LOCK,
                "GPS_Workforce_Monitor:MqttServiceWakeLock"
            )
            wakeLock?.acquire()
            android.util.Log.d("LocationMonitor", "✅ WakeLock acquired")
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

        // ✅ Read identity from Intent extras first, then fallback to prefs
        deviceId    = intent?.getStringExtra(EXTRA_DEVICE_ID)   ?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "user_name")
        companyCode = intent?.getStringExtra(EXTRA_COMPANY_CODE)?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "company_code")
        empName     = intent?.getStringExtra(EXTRA_EMP_NAME)    ?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "emp_name")

        android.util.Log.d("LocationMonitor", "identity → deviceId=$deviceId  company=$companyCode  emp=$empName  topic=$mqttTopic")

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

        wasLocationEnabled   = isLocationEnabled()
        wasPermissionGranted = checkLocationPermission()

        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clockedIn && !isFrozen) {
            if (!wasPermissionGranted) {
                android.util.Log.d("LocationMonitor", "🔐 Service restarted — permission REVOKED!")
                handler.postDelayed({ handleCriticalEvent("permission_revoked_auto") }, 500)
                return START_STICKY
            }
            if (!wasLocationEnabled) {
                android.util.Log.d("LocationMonitor", "📍 Service restarted — location OFF!")
                handler.postDelayed({ handleCriticalEvent("location_off_auto") }, 500)
                return START_STICKY
            }
            startLocationUpdates()
            connectMqtt()
        }

        startMonitoring()
        return START_STICKY
    }

    private fun startMonitoring() {
        checkRunnable = object : Runnable {
            override fun run() {
                checkLocationAndPermission()
                handler.postDelayed(this, CHECK_INTERVAL)
            }
        }
        handler.post(checkRunnable)

        gpsRunnable = object : Runnable {
            override fun run() {
                if (isClockedIn && isMqttConnected && (lastLat != 0.0 || lastLon != 0.0)) {
                    publishLocationViaMqtt()
                }
                handler.postDelayed(this, GPS_PUBLISH_MS)
            }
        }
        handler.postDelayed(gpsRunnable, GPS_PUBLISH_MS)

        // ✅ HTTP POST every 2 minutes
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
                    android.util.Log.d("LocationMonitor", "❌ [HTTP POST] Runnable error: ${e.message}")
                    if (!isDestroyed && isClockedIn) handler.postDelayed(this, HTTP_POST_MS)
                }
            }
        }.also {
            if (!isDestroyed) handler.postDelayed(it, HTTP_POST_MS)
        }

        // ✅ FIX: MQTT Watchdog — checks every 30s and reconnects if silently disconnected.
        //
        // WHY THIS IS NEEDED:
        // On aggressive OEM devices (Xiaomi/MIUI, Huawei/EMUI, Oppo/ColorOS, Vivo/FunTouch),
        // the OS kills idle TCP connections in background without firing connectionLost().
        // Without this watchdog, isMqttConnected stays true while the socket is actually dead,
        // and publishLocationViaMqtt() silently fails. The watchdog catches this and reconnects.
        val mqttWatchdog = object : Runnable {
            override fun run() {
                if (isDestroyed) return
                val prefs   = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                val frozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

                if (clocked && !frozen && !isMqttConnected && !isConnecting) {
                    android.util.Log.d("LocationMonitor", "🔁 Watchdog: MQTT not connected — reconnecting...")
                    connectMqtt()
                }
                if (!isDestroyed) handler.postDelayed(this, 30_000L)
            }
        }
        handler.postDelayed(mqttWatchdog, 30_000L)
    }

    private fun checkLocationAndPermission() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)

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
                lastEventReason = "midnight_auto"
                android.util.Log.d("LocationMonitor", "⏰ Midnight detected → handleCriticalEvent")
                handleCriticalEvent("midnight_auto")
                return
            }
        }

        val currentLocationEnabled   = isLocationEnabled()
        val currentPermissionGranted = checkLocationPermission()

        if (wasPermissionGranted && !currentPermissionGranted) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 5000 && lastEventReason != "permission_revoked_auto") {
                lastEventTime   = currentTime
                lastEventReason = "permission_revoked_auto"
                android.util.Log.d("LocationMonitor", "🔐 Permission REVOKED → handleCriticalEvent")
                handleCriticalEvent("permission_revoked_auto")
                return
            }
        }

        if (wasLocationEnabled && !currentLocationEnabled) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 5000 && lastEventReason != "location_off_auto") {
                lastEventTime   = currentTime
                lastEventReason = "location_off_auto"
                android.util.Log.d("LocationMonitor", "📍 Location OFF → handleCriticalEvent")
                handleCriticalEvent("location_off_auto")
                return
            }
        }

        wasLocationEnabled   = currentLocationEnabled
        wasPermissionGranted = currentPermissionGranted

        val status = if (currentLocationEnabled && currentPermissionGranted) {
            "Monitoring - All OK | MQTT: ${if (isMqttConnected) "●" else "○"}"
        } else {
            "Issue detected - Processing..."
        }
        updateNotification(status, false)
    }

    private fun handleCriticalEvent(reason: String) {
        val prefs         = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alreadyFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (alreadyFrozen) {
            android.util.Log.d("LocationMonitor", "⚠️ Already frozen, skipping duplicate event: $reason")
            return
        }

        val editor    = prefs.edit()
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(serviceStartTime)

        editor.putBoolean(KEY_HAS_CRITICAL_EVENT, true)
        editor.putBoolean(KEY_IS_TIMER_FROZEN, true)
        editor.putString(KEY_EVENT_TIMESTAMP, timestamp)
        editor.putString(KEY_EVENT_REASON, reason)
        editor.putBoolean(KEY_IS_CLOCKED_IN, false)
        editor.putBoolean("flutter.pending_gpx_close", true)
        editor.putString("flutter.fastClockOutTime", timestamp)
        editor.putFloat("flutter.fastClockOutDistance", 0.0f)
        editor.putString("flutter.fastClockOutReason", reason)
        editor.putBoolean("flutter.hasFastClockOutData", true)
        editor.putBoolean("flutter.clockOutPending", true)

        val clockInTime = prefs.getString("flutter.clockInTime", "") ?: ""
        val fastJson    = """{"fast_attendanceId":"","fast_userId":"","fast_clockOutTime":"$timestamp","fast_totalTime":"00:00:00","fast_totalDistance":0.0,"fast_reason":"$reason","fast_clockInTime":"$clockInTime"}"""
        editor.putString("flutter.fastClockOutData", fastJson)

        try { editor.commit() } catch (e: Exception) { editor.apply() }

        android.util.Log.d("LocationMonitor", "💾 Critical event committed: $reason at $timestamp")
        showCriticalNotification(reason, timestamp)
        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)

        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        httpPostRunnable?.let { handler.removeCallbacks(it) }

        disconnectMqtt()

        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (e: Exception) {}
        stopSelf()
    }

    private fun startLocationUpdates() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            android.util.Log.d("LocationMonitor", "No location permission")
            return
        }
        try {
            if (locationListener != null) return

            locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

            locationListener = object : LocationListener {
                override fun onLocationChanged(loc: Location) {
                    lastLat      = loc.latitude
                    lastLon      = loc.longitude
                    lastAccuracy = loc.accuracy
                    lastSpeed    = loc.speed

                    if (loc.isFromMockProvider) {
                        checkAndReportFakeGps(loc)
                    }
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
                            p, 4000L, 0f, locationListener!!, Looper.getMainLooper()
                        )
                        android.util.Log.d("LocationMonitor", "GPS registered: $p")
                    }
                } catch (e: Exception) {
                    android.util.Log.d("LocationMonitor", "GPS register failed $p: ${e.message}")
                }
            }
        } catch (e: Exception) {
            android.util.Log.d("LocationMonitor", "startLocationUpdates: ${e.message}")
        }
    }

    private fun stopLocationUpdates() {
        try { locationListener?.let { locationManager?.removeUpdates(it) } } catch (_: Exception) {}
        locationListener = null
    }

    // =========================================================
    //  connectMqtt — FIXED for reliable background operation
    //
    //  ✅ FIX 1: keepAliveInterval 60→20s
    //     OEM devices (MIUI, EMUI, ColorOS) kill idle TCP sockets
    //     in ~15–30s in background. A 60s keepalive means the broker
    //     thinks the client is alive while the socket is already dead.
    //
    //  ✅ FIX 2: connectionTimeout 10→15s
    //     Gives slow mobile networks more time to complete the TCP
    //     handshake, reducing spurious onFailure callbacks.
    //
    //  ✅ FIX 3: 15s safety timeout resets stuck isConnecting flag
    //     On some OEM devices, neither onSuccess nor onFailure fires
    //     when the system kills the connection attempt mid-flight.
    //     This leaves isConnecting=true permanently, causing every
    //     subsequent connectMqtt() call to return early. The timeout
    //     detects this and resets the flag so retries can proceed.
    //
    //  ✅ FIX 4: Exception block now schedules a retry
    //     Previously an exception left the client in a broken state
    //     with no recovery. Now it always retries after 5s.
    // =========================================================
    private fun connectMqtt() {
        if (isMqttConnected) return
        if (!isNetworkAvailable()) {
            android.util.Log.d("LocationMonitor", "No network — will retry when network returns")
            return
        }

        // Guard: avoid duplicate simultaneous connection attempts
        if (isConnecting) {
            android.util.Log.d("LocationMonitor", "Already connecting — skipping duplicate call")
            return
        }

        isConnecting = true

        // ✅ FIX 3: Safety timeout — if onSuccess/onFailure never fires (OEM bug),
        //           reset isConnecting after 15s so the watchdog can retry.
        handler.postDelayed({
            if (isConnecting && !isMqttConnected && !isDestroyed) {
                android.util.Log.d("LocationMonitor", "⚠️ MQTT connect timed out silently — resetting flag")
                isConnecting = false
                safeCloseClient()
                handler.postDelayed({ connectMqtt() }, 3000L)
            }
        }, 15_000L)

        try {
            val clientId = "android_bg_${System.currentTimeMillis()}"
            android.util.Log.d("LocationMonitor", "Connecting to tcp://$MQTT_HOST:$MQTT_PORT id=$clientId  topic=$mqttTopic")

            safeCloseClient()

            mqttClient = MqttAsyncClient(
                "tcp://$MQTT_HOST:$MQTT_PORT", clientId, MemoryPersistence()
            )

            mqttClient?.setCallback(object : MqttCallback {
                override fun connectionLost(cause: Throwable?) {
                    isMqttConnected = false
                    isConnecting    = false
                    android.util.Log.d("LocationMonitor", "Connection lost: ${cause?.message}")
                    if (!isDestroyed) handler.postDelayed({ connectMqtt() }, 3000L)
                }
                override fun messageArrived(topic: String?, message: MqttMessage?) {}
                override fun deliveryComplete(token: IMqttDeliveryToken?) {}
            })

            val opts = MqttConnectOptions().apply {
                isCleanSession       = true
                keepAliveInterval    = 20    // ✅ FIX 1: was 60 — prevents silent TCP death on OEM devices
                connectionTimeout    = 15    // ✅ FIX 2: was 10 — more time for slow networks
                isAutomaticReconnect = false // watchdog + connectionLost handle reconnection
            }

            mqttClient?.connect(opts, null, object : IMqttActionListener {
                override fun onSuccess(asyncActionToken: IMqttToken?) {
                    isMqttConnected = true
                    isConnecting    = false
                    android.util.Log.d("LocationMonitor", "✅ MQTT Connected! topic=$mqttTopic")
                    updateNotification("Online | GPS publishing → $mqttTopic", false)
                }
                override fun onFailure(asyncActionToken: IMqttToken?, exception: Throwable?) {
                    isMqttConnected = false
                    isConnecting    = false
                    android.util.Log.d("LocationMonitor", "Connect failed: ${exception?.message}")
                    if (!isDestroyed) handler.postDelayed({ connectMqtt() }, 5000L)
                }
            })
        } catch (e: Exception) {
            isMqttConnected = false
            isConnecting    = false
            android.util.Log.d("LocationMonitor", "Exception in connectMqtt: ${e.message}")
            // ✅ FIX 4: was missing — now always schedules a retry on exception
            if (!isDestroyed) handler.postDelayed({ connectMqtt() }, 5000L)
        }
    }

    private fun publishLocationViaMqtt() {
        if (!isMqttConnected || (lastLat == 0.0 && lastLon == 0.0)) return
        try {
            val payload = buildPayload()
            val msg     = MqttMessage(payload.toByteArray(Charsets.UTF_8))
            msg.qos     = 1
            mqttClient?.publish(mqttTopic, msg)
            android.util.Log.d("LocationMonitor", "📤 Published ✓ lat=$lastLat lon=$lastLon → $mqttTopic")
        } catch (e: Exception) {
            android.util.Log.d("LocationMonitor", "Publish error: ${e.message}")
            isMqttConnected = false
        }
    }

    private fun buildPayload(): String {
        val ts = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).format(Date())
        return JSONObject().apply {
            put("device_id",    deviceId)
            put("company_code", companyCode)
            put("emp_name",     empName)
            put("track_id",     System.currentTimeMillis())
            put("lat",          lastLat)
            put("lon",          lastLon)
            put("accuracy",     lastAccuracy.toDouble())
            put("speed",        lastSpeed.toDouble())
            put("timestamp",    ts)
            put("source",       "android_background_service")
        }.toString()
    }

    // =========================================================
    //  HTTP POST — every 2 minutes
    //  ✅ FIX APPLIED: prefString() used everywhere instead of
    //  prefs.getString() to avoid ClassCastException when Flutter
    //  has stored emp_id (or any other field) as a Long/Int.
    // =========================================================
    private fun postLocationToApi() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            // -------------------------------------------------------
            // 1. Resolve emp_id — try known keys in priority order.
            //    prefString() handles Long, Int, String transparently.
            // -------------------------------------------------------
            val empIdKeys = listOf(
                "flutter.emp_id",
                "emp_id",
                "flutter.empId",
                "empId",
                "flutter.user_id",
                "user_id",
                "flutter.userId",
                "userId"
            )

            var empId = ""
            for (key in empIdKeys) {
                // ✅ FIX: use prefString() — safe for ANY stored type
                val value = prefString(prefs, key)
                if (value.isNotEmpty()) {
                    empId = value
                    android.util.Log.d("LocationMonitor", "✅ Found emp_id using key: '$key' = '$empId'")
                    break
                }
            }

            // Fallback: full scan of all prefs if still empty
            if (empId.isEmpty()) {
                try {
                    for ((key, raw) in prefs.all) {
                        if (key.contains("emp_id", ignoreCase = true) ||
                            key.contains("empId", ignoreCase = true) ||
                            key.contains("user_id", ignoreCase = true) ||
                            key.contains("userId", ignoreCase = true)
                        ) {
                            // ✅ FIX: toString() handles Long/Int/String safely
                            val candidate = raw?.toString()?.trim() ?: ""
                            if (candidate.isNotEmpty() && candidate != "null") {
                                empId = candidate
                                android.util.Log.d("LocationMonitor", "✅ Found emp_id via scan: '$key' = '$empId'")
                                break
                            }
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.d("LocationMonitor", "⚠️ Error scanning all prefs: ${e.message}")
                }
            }

            if (empId.isEmpty()) {
                android.util.Log.d("LocationMonitor", "⚠️ [HTTP POST] emp_id empty — skipping POST")
                return
            }

            // -------------------------------------------------------
            // 2. Resolve location
            // -------------------------------------------------------
            var lat = lastLat
            var lon = lastLon

            if (lat == 0.0 && lon == 0.0) {
                try {
                    val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    val providers = listOf(
                        LocationManager.GPS_PROVIDER,
                        LocationManager.NETWORK_PROVIDER,
                        LocationManager.PASSIVE_PROVIDER
                    )
                    for (p in providers) {
                        if (ContextCompat.checkSelfPermission(
                                this, Manifest.permission.ACCESS_FINE_LOCATION
                            ) == PackageManager.PERMISSION_GRANTED
                        ) {
                            val loc = lm.getLastKnownLocation(p)
                            if (loc != null) {
                                lat = loc.latitude
                                lon = loc.longitude
                                android.util.Log.d("LocationMonitor", "✅ Got location from $p: $lat, $lon")
                                break
                            }
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.d("LocationMonitor", "⚠️ [HTTP POST] lastKnown failed: ${e.message}")
                }
            }

            if (lat == 0.0 && lon == 0.0) {
                android.util.Log.d("LocationMonitor", "⚠️ [HTTP POST] No location available — skipping")
                return
            }

            // -------------------------------------------------------
            // 3. Resolve emp_name & company_code
            //    ✅ FIX: prefString() used here too — avoids cast errors
            // -------------------------------------------------------
            var name    = empName
            if (name.isEmpty()) {
                name = prefString(prefs, "flutter.emp_name")
                if (name.isEmpty()) name = prefString(prefs, "emp_name")
            }

            var company = companyCode
            if (company.isEmpty()) {
                company = prefString(prefs, "flutter.company_code")
                if (company.isEmpty()) company = prefString(prefs, "company_code")
            }

            // Snapshot before background thread
            val snapLat  = lat
            val snapLon  = lon
            val snapEmp  = empId
            val snapName = name
            val snapCo   = company

            // -------------------------------------------------------
            // 4. Network call on background thread
            // -------------------------------------------------------
            Thread {
                try {
                    // Battery
                    val bm      = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val battery = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        .coerceIn(0, 100)

                    // Reverse geocode (optional)
                    var address = ""
                    try {
                        @Suppress("DEPRECATION")
                        val results = Geocoder(applicationContext, JavaLocale.getDefault())
                            .getFromLocation(snapLat, snapLon, 1)
                        if (!results.isNullOrEmpty()) {
                            val a = results[0]
                            address = listOfNotNull(
                                a.thoroughfare,
                                a.subLocality,
                                a.locality,
                                a.adminArea,
                                a.countryName
                            ).filter { it.isNotEmpty() }.joinToString(", ")
                        }
                    } catch (ge: Exception) {
                        android.util.Log.d("LocationMonitor", "⚠️ [HTTP POST] Geocode: ${ge.message}")
                    }

                    val trackDate = SimpleDateFormat(
                        "dd-MM-yyyy HH:mm:ss", Locale.getDefault()
                    ).format(Date())

                    // ✅ JSON body — all values explicitly typed to
                    //    avoid JSONObject auto-boxing surprises
                    val json = JSONObject().apply {
                        put("lat",             snapLat)            // Double
                        put("lng",             snapLon)            // Double
                        put("emp_id",          snapEmp)            // String
                        put("emp_name",        snapName)           // String
                        put("company_code",    snapCo)             // String
                        put("track_date",      trackDate)          // String
                        put("battery_percent", battery)            // Int
                        put("address",         address)            // String
                    }.toString()

                    android.util.Log.d(
                        "LocationMonitor",
                        "📡 [HTTP POST] Sending → lat=$snapLat lng=$snapLon emp_id=$snapEmp"
                    )

                    val conn = (URL(HTTP_POST_URL).openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("Accept",       "application/json")
                        doOutput       = true
                        connectTimeout = 15000
                        readTimeout    = 15000
                    }

                    OutputStreamWriter(conn.outputStream).use { it.write(json) }
                    val responseCode = conn.responseCode

                    if (responseCode in 200..299) {
                        android.util.Log.d("LocationMonitor", "✅ [HTTP POST] SUCCESS — Status: $responseCode")
                    } else {
                        android.util.Log.d("LocationMonitor", "❌ [HTTP POST] FAILED — Status: $responseCode")
                        try {
                            val err = conn.errorStream?.bufferedReader()?.readText()
                            android.util.Log.d("LocationMonitor", "   Error body: $err")
                        } catch (_: Exception) {}
                    }

                    conn.disconnect()

                } catch (e: Exception) {
                    android.util.Log.d("LocationMonitor", "❌ [HTTP POST] Thread exception: ${e.message}")
                    e.printStackTrace()
                }
            }.start()

        } catch (e: Exception) {
            android.util.Log.d("LocationMonitor", "❌ [HTTP POST] Outer exception: ${e.message}")
        }
    }

    private fun checkAndReportFakeGps(loc: Location) {
        val now = System.currentTimeMillis()
        if (now - lastFakeGpsReportTime < FAKE_GPS_COOLDOWN_MS) return
        lastFakeGpsReportTime = now

        android.util.Log.d("LocationMonitor", "🚨 [FakeGPS] Mock location! lat=${loc.latitude} lon=${loc.longitude}")

        val prefs  = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        // ✅ FIX: prefString() instead of getString()
        val empId  = prefString(prefs, "emp_id")
        val detectedAt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())

        val json = JSONObject().apply {
            put("emp_id",       empId)
            put("emp_name",     empName)
            put("company_code", companyCode)
            put("latitude",     loc.latitude)
            put("longitude",    loc.longitude)
            put("detected_at",  detectedAt)
        }.toString()

        Thread {
            try {
                val conn = (URL(FAKE_GPS_API).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    doOutput       = true
                    connectTimeout = 10_000
                    readTimeout    = 10_000
                }
                OutputStreamWriter(conn.outputStream).use { it.write(json) }
                android.util.Log.d("LocationMonitor", "✅ [FakeGPS] POST → ${conn.responseCode}")
                conn.disconnect()
            } catch (e: Exception) {
                android.util.Log.d("LocationMonitor", "❌ [FakeGPS] POST failed: ${e.message}")
            }
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
                    android.util.Log.d("LocationMonitor", "Network available — reconnecting MQTT")
                    handler.post { connectMqtt() }
                }
                override fun onLost(network: Network) {
                    android.util.Log.d("LocationMonitor", "Network lost")
                    isMqttConnected = false
                }
            }
            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
        } catch (e: Exception) {
            android.util.Log.d("LocationMonitor", "registerNetworkCallback error: ${e.message}")
        }
    }

    private fun unregisterNetworkCallback() {
        try { networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) } } catch (_: Exception) {}
        networkCallback = null
    }

    private fun registerAppOpsListener() {
        try {
            appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val listener  = AppOpsManager.OnOpChangedListener { _, pkg ->
                if (pkg == packageName) {
                    handler.post { checkLocationAndPermission() }
                }
            }
            appOpsManager?.startWatchingMode(
                AppOpsManager.OPSTR_FINE_LOCATION,
                this@LocationMonitorService.packageName,
                listener
            )
            appOpsCallback = listener
            android.util.Log.d("LocationMonitor", "✅ AppOps listener registered")
        } catch (e: Exception) {
            android.util.Log.d("LocationMonitor", "⚠️ AppOps listener failed: ${e.message}")
        }
    }

    private fun unregisterAppOpsListener() {
        try {
            val cb = appOpsCallback
            if (cb != null) {
                appOpsManager?.stopWatchingMode(cb)
                appOpsCallback = null
            }
        } catch (e: Exception) {
            android.util.Log.d("LocationMonitor", "Error unregistering: ${e.message}")
        }
    }

    private fun registerReceivers() {
        val locationModeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == LocationManager.MODE_CHANGED_ACTION) {
                    android.util.Log.d("LocationMonitor", "Location mode changed")
                    handler.post { checkLocationAndPermission() }
                }
            }
        }
        registerReceiver(locationModeReceiver, IntentFilter(LocationManager.MODE_CHANGED_ACTION))

        val dateTimeChangeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                if (action in listOf(
                        Intent.ACTION_TIME_CHANGED,
                        Intent.ACTION_DATE_CHANGED,
                        Intent.ACTION_TIMEZONE_CHANGED
                    )
                ) {
                    val prefs   = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                    val frozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

                    if (clocked && !frozen) {
                        val now = System.currentTimeMillis()
                        if (now - lastEventTime > 5000 && lastEventReason != "time_changed_auto") {
                            lastEventTime   = now
                            lastEventReason = "time_changed_auto"
                            android.util.Log.d("LocationMonitor", "⏰ Date/Time changed")
                            handleCriticalEvent("time_changed_auto")
                        }
                    }
                }
            }
        }
        val dateTimeFilter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        registerReceiver(dateTimeChangeReceiver, dateTimeFilter)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID, "Location Monitor Service", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Monitors location + MQTT GPS publishing" }

            val urgentChannel = NotificationChannel(
                URGENT_CHANNEL_ID, "URGENT Auto Clockout", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical auto clockout notifications"
                enableVibration(true)
                enableLights(true)
                lightColor = android.graphics.Color.RED
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
            manager.createNotificationChannel(urgentChannel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Attendance Active")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun updateNotification(text: String, isAlert: Boolean) {
        val launchIntent  = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(if (isAlert) "⚠️ ATTENTION REQUIRED" else "Attendance Active")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(!isAlert)
            .apply {
                if (isAlert) {
                    setColor(android.graphics.Color.RED)
                    setLights(android.graphics.Color.RED, 1000, 500)
                }
            }
            .build()

        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }

    private fun showCriticalNotification(reason: String, time: String) {
        val title = when (reason) {
            "location_off_auto"       -> "⚠️ LOCATION TURNED OFF"
            "permission_revoked_auto" -> "⚠️ PERMISSION REVOKED"
            "midnight_auto"           -> "⚠️ MIDNIGHT AUTO CLOCKOUT"
            else                      -> "⚠️ AUTO CLOCKOUT"
        }
        val message      = "Time: $time\nApp was closed - Event captured. Open app to sync."
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(this, URGENT_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 1000, 500, 1000))
            .setLights(android.graphics.Color.RED, 1000, 500)
            .build()

        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(9999, notification)
    }

    private fun isLocationEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            (getSystemService(Context.LOCATION_SERVICE) as LocationManager).isLocationEnabled
        } else {
            try {
                Settings.Secure.getInt(
                    contentResolver, Settings.Secure.LOCATION_MODE,
                    Settings.Secure.LOCATION_MODE_OFF
                ) != Settings.Secure.LOCATION_MODE_OFF
            } catch (e: Exception) { false }
        }
    }

    private fun checkLocationPermission(): Boolean {
        return try {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
                    PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                    PackageManager.PERMISSION_GRANTED
        } catch (e: Exception) { false }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        android.util.Log.d("LocationMonitor", "App removed from recents — scheduling service restart")

        val prefs   = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val frozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clocked && !frozen) {
            val restartIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
                putExtra(EXTRA_DEVICE_ID,    deviceId)
                putExtra(EXTRA_COMPANY_CODE, companyCode)
                putExtra(EXTRA_EMP_NAME,     empName)
            }
            val pi = PendingIntent.getService(
                applicationContext, 1, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerTime  = android.os.SystemClock.elapsedRealtime() + 1000L
            // ✅ FIX: On Android 12+ (API 31+) SCHEDULE_EXACT_ALARM requires
            //         runtime user grant — not just manifest declaration.
            //         Check canScheduleExactAlarms() before calling the exact API.
            //         Fall back to setAndAllowWhileIdle (inexact but safe) if not granted.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi
                )
            } else {
                alarmManager.set(AlarmManager.ELAPSED_REALTIME, triggerTime, pi)
            }
        }
    }

    override fun onDestroy() {
        android.util.Log.d("LocationMonitor", "🛑 Service onDestroy called")
        isDestroyed = true

        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        httpPostRunnable?.let { handler.removeCallbacks(it) }

        stopLocationUpdates()
        disconnectMqtt()
        unregisterNetworkCallback()
        unregisterAppOpsListener()

        // ✅ FIX: Release WakeLock on service stop
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                android.util.Log.d("LocationMonitor", "✅ WakeLock released")
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "WakeLock release failed: ${e.message}")
        }

        super.onDestroy()
    }
}