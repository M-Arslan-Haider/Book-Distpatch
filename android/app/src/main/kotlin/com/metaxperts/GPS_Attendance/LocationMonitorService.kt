//// ============================================================
////  LocationMonitorService.kt — BACKGROUND MQTT FIX
////
////  BUGS FIXED:
////    1. Identity (deviceId/companyCode/empName) now persisted to
////       SharedPreferences so boot/restart recovers them
////    2. PARTIAL_WAKE_LOCK replaces deprecated FULL_WAKE_LOCK
////    3. Network callback no longer nukes all handler runnables
////    4. Removed screen wake lock cycling (caused OEM battery kill)
////    5. MQTT keepAlive = 30 to match Dart client
//// ============================================================
//
//package com.metaxperts.GPS_Workforce_Monitor
//
//import android.app.AppOpsManager
//import android.app.AlarmManager
//import android.app.Notification
//import android.app.NotificationChannel
//import android.app.NotificationManager
//import android.app.PendingIntent
//import android.app.Service
//import android.content.BroadcastReceiver
//import android.content.Context
//import android.content.Intent
//import android.content.IntentFilter
//import android.content.pm.PackageManager
//import android.content.pm.ServiceInfo
//import android.location.Location
//import android.location.LocationListener
//import android.location.LocationManager
//import android.net.ConnectivityManager
//import android.net.Network
//import android.net.NetworkCapabilities
//import android.net.NetworkRequest
//import android.os.Build
//import android.os.Bundle
//import android.os.Handler
//import android.os.IBinder
//import android.os.Looper
//import android.provider.Settings
//import androidx.core.app.NotificationCompat
//import androidx.core.content.ContextCompat
//import android.Manifest
//
//import org.eclipse.paho.client.mqttv3.IMqttActionListener
//import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken
//import org.eclipse.paho.client.mqttv3.IMqttToken
//import org.eclipse.paho.client.mqttv3.MqttAsyncClient
//import org.eclipse.paho.client.mqttv3.MqttCallback
//import org.eclipse.paho.client.mqttv3.MqttConnectOptions
//import org.eclipse.paho.client.mqttv3.MqttMessage
//import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence
//
//import org.json.JSONObject
//
//import java.io.OutputStreamWriter
//import java.net.HttpURLConnection
//import java.net.URL
//
//import android.os.BatteryManager
//import android.location.Geocoder
//import java.util.Locale as JavaLocale
//
//import java.text.SimpleDateFormat
//import java.util.Date
//import java.util.Locale
//
//class LocationMonitorService : Service() {
//    private val CHANNEL_ID        = "location_monitor_channel"
//    private val URGENT_CHANNEL_ID = "urgent_auto_clockout_channel"
//    private val NOTIFICATION_ID   = 1001
//    private val CHECK_INTERVAL    = 2000L
//    private val GPS_PUBLISH_MS    = 5000L
//
//    private val HTTP_POST_MS  = 2 * 60 * 1000L
//    private val HTTP_POST_URL = "http://oracle.metaxperts.net/ords/gps_workforce/emplocation/post/"
//
//    private val MQTT_HOST = "103.149.33.102"
//    private val MQTT_PORT = 1883
//
//    private val mqttTopic get() = "gps/$companyCode/$deviceId"
//
//    private val PREFS_NAME             = "FlutterSharedPreferences"
//    private val KEY_IS_CLOCKED_IN      = "flutter.isClockedIn"
//    private val KEY_HAS_CRITICAL_EVENT = "flutter.has_critical_event_pending"
//    private val KEY_EVENT_TIMESTAMP    = "flutter.critical_event_timestamp"
//    private val KEY_EVENT_REASON       = "flutter.critical_event_reason"
//    private val KEY_IS_TIMER_FROZEN    = "flutter.is_timer_frozen"
//    private val KEY_ELAPSED_TIME       = "flutter.elapsed_time"
//
//    private lateinit var handler: Handler
//    private var checkRunnable: Runnable     = Runnable {}
//    private var gpsRunnable: Runnable       = Runnable {}
//    private var httpPostRunnable: Runnable? = null
//    private var watchdogRunnable: Runnable? = null
//    private var heartbeatRunnable: Runnable? = null
//    private var isDestroyed = false
//
//    // FIX #2: PARTIAL_WAKE_LOCK — the ONLY type that prevents CPU sleep
//    private var wakeLock: android.os.PowerManager.WakeLock? = null
//
//    private var wasLocationEnabled   = true
//    private var wasPermissionGranted = true
//    private var isClockedIn          = false
//    private var lastEventTime: Long  = 0
//    private var lastEventReason: String = ""
//    private var serviceStartTime: Date  = Date()
//
//    private var lastLat      = 0.0
//    private var lastLon      = 0.0
//    private var lastAccuracy = 0f
//    private var lastSpeed    = 0f
//    private var lastHeartbeatTime: Long = 0
//    private var locationManager: LocationManager? = null
//    private var locationListener: LocationListener? = null
//
//    private var mqttClient: MqttAsyncClient? = null
//    private var isMqttConnected = false
//    private var isConnecting    = false
//    private var connectivityManager: ConnectivityManager? = null
//    private var networkCallback: ConnectivityManager.NetworkCallback? = null
//
//    private var appOpsManager: AppOpsManager? = null
//    private var appOpsCallback: AppOpsManager.OnOpChangedListener? = null
//
//    private var deviceId    = ""
//    private var companyCode = ""
//    private var empName     = ""
//
//    private val FAKE_GPS_API         = "http://oracle.metaxperts.net/ords/gps_workforce/fakegps/post/"
//    private var lastFakeGpsReportTime: Long = 0
//    private val FAKE_GPS_COOLDOWN_MS = 30_000L
//
//    companion object {
//        const val EXTRA_DEVICE_ID    = "deviceId"
//        const val EXTRA_COMPANY_CODE = "companyCode"
//        const val EXTRA_EMP_NAME     = "empName"
//
//        fun start(context: Context) {
//            try {
//                val i = Intent(context, LocationMonitorService::class.java)
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                    context.startForegroundService(i)
//                } else {
//                    context.startService(i)
//                }
//            } catch (e: Exception) {
//                android.util.Log.e("LocationMonitor", "start: ${e.message}")
//            }
//        }
//
//        fun start(context: Context, deviceId: String, companyCode: String, empName: String) {
//            try {
//                val i = Intent(context, LocationMonitorService::class.java).apply {
//                    putExtra(EXTRA_DEVICE_ID,    deviceId)
//                    putExtra(EXTRA_COMPANY_CODE, companyCode)
//                    putExtra(EXTRA_EMP_NAME,     empName)
//                }
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                    context.startForegroundService(i)
//                } else {
//                    context.startService(i)
//                }
//            } catch (e: Exception) {
//                android.util.Log.e("LocationMonitor", "start(identity): ${e.message}")
//            }
//        }
//
//        fun stop(context: Context) {
//            try {
//                context.stopService(Intent(context, LocationMonitorService::class.java))
//            } catch (e: Exception) {
//                android.util.Log.e("LocationMonitor", "stop: ${e.message}")
//            }
//        }
//    }
//
//    private fun parseTimeTo24h(raw: String): Pair<Int, Int>? {
//        return try {
//            val upper   = raw.trim().uppercase()
//            val isPM    = upper.contains("PM")
//            val isAM    = upper.contains("AM")
//            val cleaned = upper.replace("PM", "").replace("AM", "").trim()
//            val parts   = cleaned.split(":")
//            if (parts.size < 2) return null
//            var hour   = parts[0].trim().toIntOrNull() ?: return null
//            val minute = parts[1].trim().split(Regex("\\s+"))[0].toIntOrNull() ?: return null
//            if (isPM && hour != 12) hour += 12
//            if (isAM && hour == 12) hour  = 0
//            Pair(hour, minute)
//        } catch (e: Exception) {
//            null
//        }
//    }
//
//    private fun prefString(prefs: android.content.SharedPreferences, key: String): String {
//        return try {
//            val raw = prefs.all[key] ?: return ""
//            val str = raw.toString().trim()
//            if (str == "null") "" else str
//        } catch (e: Exception) {
//            ""
//        }
//    }
//
//    override fun onCreate() {
//        super.onCreate()
//        handler = Handler(Looper.getMainLooper())
//
//        // FIX #2: PARTIAL_WAKE_LOCK keeps CPU running even when screen is off
//        try {
//            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
//            wakeLock = pm.newWakeLock(
//                android.os.PowerManager.PARTIAL_WAKE_LOCK,
//                "GPS_Workforce_Monitor:MqttBgLock"
//            )
//            wakeLock?.acquire()
//            android.util.Log.d("LocationMonitor", "✅ PARTIAL_WAKE_LOCK acquired")
//        } catch (e: Exception) {
//            android.util.Log.e("LocationMonitor", "WakeLock acquire failed: ${e.message}")
//        }
//
//        registerReceivers()
//        registerNetworkCallback()
//        registerAppOpsListener()
//    }
//
//    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//        createNotificationChannel()
//        serviceStartTime = Date()
//
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//
//        // FIX #1: Read identity from Intent extras first, fall back to prefs
//        deviceId    = intent?.getStringExtra(EXTRA_DEVICE_ID)?.takeIf { it.isNotEmpty() }
//            ?: prefString(prefs, "user_name")
//        companyCode = intent?.getStringExtra(EXTRA_COMPANY_CODE)?.takeIf { it.isNotEmpty() }
//            ?: prefString(prefs, "company_code")
//        empName     = intent?.getStringExtra(EXTRA_EMP_NAME)?.takeIf { it.isNotEmpty() }
//            ?: prefString(prefs, "emp_name")
//
//        // FIX #1b: Persist identity so boot receiver / alarm restart can recover
//        prefs.edit().apply {
//            if (deviceId.isNotEmpty())    putString("user_name",    deviceId)
//            if (companyCode.isNotEmpty()) putString("company_code", companyCode)
//            if (empName.isNotEmpty())     putString("emp_name",     empName)
//            apply()
//        }
//
//        android.util.Log.d("LocationMonitor",
//            "identity → deviceId=$deviceId  company=$companyCode  emp=$empName  topic=$mqttTopic")
//
//        try {
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
//                startForeground(
//                    NOTIFICATION_ID, buildNotification("Initialising..."),
//                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
//                )
//            } else {
//                startForeground(NOTIFICATION_ID, buildNotification("Initialising..."))
//            }
//        } catch (e: Exception) {
//            android.util.Log.d("LocationMonitor", "startForeground failed: ${e.message}")
//            stopSelf()
//            return START_NOT_STICKY
//        }
//
//        wasLocationEnabled   = isLocationEnabled()
//        wasPermissionGranted = checkLocationPermission()
//
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        if (clockedIn && !isFrozen) {
//            if (!wasPermissionGranted) {
//                handler.postDelayed({ handleCriticalEvent("permission_revoked_auto") }, 500)
//                return START_STICKY
//            }
//            if (!wasLocationEnabled) {
//                handler.postDelayed({ handleCriticalEvent("System Clockout - Location Off") }, 500)
//                return START_STICKY
//            }
//            startLocationUpdates()
//            connectMqtt()
//        }
//
//        startMonitoring()
//        return START_STICKY
//    }
//
//    private fun startMonitoring() {
//        checkRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                checkLocationAndPermission()
//                handler.postDelayed(this, CHECK_INTERVAL)
//            }
//        }
//        handler.post(checkRunnable)
//
//        gpsRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                if (isClockedIn && isMqttConnected && (lastLat != 0.0 || lastLon != 0.0)) {
//                    publishLocationViaMqtt()
//                }
//                handler.postDelayed(this, GPS_PUBLISH_MS)
//            }
//        }
//        handler.postDelayed(gpsRunnable, GPS_PUBLISH_MS)
//
//        httpPostRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed || !isClockedIn) return
//                try {
//                    val p       = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                    val clocked = p.getBoolean(KEY_IS_CLOCKED_IN, false)
//                    val frozen  = p.getBoolean(KEY_IS_TIMER_FROZEN, false)
//                    if (clocked && !frozen && isNetworkAvailable()) {
//                        postLocationToApi()
//                    }
//                    if (!isDestroyed) handler.postDelayed(this, HTTP_POST_MS)
//                } catch (e: Exception) {
//                    if (!isDestroyed && isClockedIn) handler.postDelayed(this, HTTP_POST_MS)
//                }
//            }
//        }.also {
//            if (!isDestroyed) handler.postDelayed(it, HTTP_POST_MS)
//        }
//
//        startMqttWatchdog()
//        startHeartbeatWatchdog()
//    }
//
//    private fun startMqttWatchdog() {
//        var consecutiveFailures = 0
//        watchdogRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//                val frozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//                if (clocked && !frozen) {
//                    if (!isMqttConnected && !isConnecting && isNetworkAvailable()) {
//                        consecutiveFailures++
//                        android.util.Log.d("LocationMonitor",
//                            "🔁 [WATCHDOG] MQTT not connected — Attempt #$consecutiveFailures")
//                        connectMqtt()
//                    } else if (isMqttConnected) {
//                        consecutiveFailures = 0
//                    }
//                } else {
//                    consecutiveFailures = 0
//                }
//                if (!isDestroyed) handler.postDelayed(this, 15_000L)
//            }
//        }
//        handler.postDelayed(watchdogRunnable!!, 15_000L)
//    }
//
//    private fun startHeartbeatWatchdog() {
//        heartbeatRunnable = object : Runnable {
//            override fun run() {
//                if (isDestroyed) return
//                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//                val frozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//                if (clocked && !frozen) {
//                    val now = System.currentTimeMillis()
//                    if (now - lastHeartbeatTime > 12_000L) {
//                        lastHeartbeatTime = now
//                        if (isMqttConnected && (lastLat != 0.0 || lastLon != 0.0)) {
//                            publishLocationViaMqtt()
//                        }
//                    }
//                }
//                if (!isDestroyed) handler.postDelayed(this, 5_000L)
//            }
//        }
//        handler.postDelayed(heartbeatRunnable!!, 5_000L)
//    }
//
//    private fun checkLocationAndPermission() {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//
//        if (!isClockedIn) {
//            updateNotification("Not clocked in", false)
//            return
//        }
//
//        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//        if (isFrozen) {
//            handler.removeCallbacks(checkRunnable)
//            return
//        }
//
//        val calendar = java.util.Calendar.getInstance()
//        val hour   = calendar.get(java.util.Calendar.HOUR_OF_DAY)
//        val minute = calendar.get(java.util.Calendar.MINUTE)
//
//        if (hour == 23 && minute == 58) {
//            val currentTime = System.currentTimeMillis()
//            if (currentTime - lastEventTime > 60000) {
//                lastEventTime   = currentTime
//                lastEventReason = "System Clockout - Midnight Time"
//                handleCriticalEvent("System Clockout - Midnight Time")
//                return
//            }
//        }
//
//        val cachedEndTime = prefString(prefs, "flutter.cached_end_time")
//        if (cachedEndTime.isNotEmpty()) {
//            try {
//                val overtime = prefString(prefs, "flutter.cached_overtime").lowercase()
//                val overtimeAllowed = overtime == "yes" || overtime == "y" || overtime == "true"
//                if (!overtimeAllowed) {
//                    val parsed = parseTimeTo24h(cachedEndTime)
//                    if (parsed != null) {
//                        val endTotalMin = parsed.first * 60 + parsed.second
//                        val nowTotalMin = hour * 60 + minute
//                        val diffMin     = nowTotalMin - endTotalMin
//                        if (diffMin in 0..480) {
//                            val currentTime = System.currentTimeMillis()
//                            if (currentTime - lastEventTime > 60000 && lastEventReason != "System Clockout - Shift End") {
//                                lastEventTime   = currentTime
//                                lastEventReason = "System Clockout - Shift End"
//                                handleCriticalEvent("System Clockout - Shift End")
//                                return
//                            }
//                        }
//                    }
//                }
//            } catch (_: Exception) {}
//        }
//
//        val currentLocationEnabled   = isLocationEnabled()
//        val currentPermissionGranted = checkLocationPermission()
//
//        if (wasPermissionGranted && !currentPermissionGranted) {
//            val currentTime = System.currentTimeMillis()
//            if (currentTime - lastEventTime > 5000 && lastEventReason != "permission_revoked_auto") {
//                lastEventTime   = currentTime
//                lastEventReason = "permission_revoked_auto"
//                handleCriticalEvent("permission_revoked_auto")
//                return
//            }
//        }
//
//        if (wasLocationEnabled && !currentLocationEnabled) {
//            val currentTime = System.currentTimeMillis()
//            if (currentTime - lastEventTime > 5000 && lastEventReason != "System Clockout - Location Off") {
//                lastEventTime   = currentTime
//                lastEventReason = "System Clockout - Location Off"
//                handleCriticalEvent("System Clockout - Location Off")
//                return
//            }
//        }
//
//        wasLocationEnabled   = currentLocationEnabled
//        wasPermissionGranted = currentPermissionGranted
//
//        val status = if (currentLocationEnabled && currentPermissionGranted) {
//            "Monitoring - All OK | MQTT: ${if (isMqttConnected) "●" else "○"}"
//        } else {
//            "Issue detected - Processing..."
//        }
//        updateNotification(status, false)
//    }
//
//    private fun handleCriticalEvent(reason: String) {
//        val prefs         = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val alreadyFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//        if (alreadyFrozen) return
//
//        val editor    = prefs.edit()
//        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())
//
//        editor.putBoolean(KEY_HAS_CRITICAL_EVENT, true)
//        editor.putBoolean(KEY_IS_TIMER_FROZEN, true)
//        editor.putString(KEY_EVENT_TIMESTAMP, timestamp)
//        editor.putString(KEY_EVENT_REASON, reason)
//        editor.putBoolean(KEY_IS_CLOCKED_IN, false)
//        editor.putBoolean("flutter.pending_gpx_close", true)
//        editor.putString("flutter.fastClockOutTime", timestamp)
//        editor.putFloat("flutter.fastClockOutDistance", 0.0f)
//        editor.putString("flutter.fastClockOutReason", reason)
//        editor.putBoolean("flutter.hasFastClockOutData", true)
//        editor.putBoolean("flutter.clockOutPending", true)
//
//        val clockInTime = prefs.getString("flutter.clockInTime", "") ?: ""
//        val fastJson = """{"fast_attendanceId":"","fast_userId":"","fast_clockOutTime":"$timestamp","fast_totalTime":"00:00:00","fast_totalDistance":0.0,"fast_reason":"$reason","fast_clockInTime":"$clockInTime"}"""
//        editor.putString("flutter.fastClockOutData", fastJson)
//
//        try { editor.commit() } catch (e: Exception) { editor.apply() }
//
//        showCriticalNotification(reason, timestamp)
//        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)
//
//        handler.removeCallbacks(checkRunnable)
//        handler.removeCallbacks(gpsRunnable)
//        httpPostRunnable?.let { handler.removeCallbacks(it) }
//        watchdogRunnable?.let { handler.removeCallbacks(it) }
//        heartbeatRunnable?.let { handler.removeCallbacks(it) }
//
//        disconnectMqtt()
//
//        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
//        stopSelf()
//    }
//
//    private fun startLocationUpdates() {
//        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
//            != PackageManager.PERMISSION_GRANTED &&
//            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
//            != PackageManager.PERMISSION_GRANTED
//        ) return
//
//        try {
//            if (locationListener != null) return
//            locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
//
//            locationListener = object : LocationListener {
//                override fun onLocationChanged(loc: Location) {
//                    lastLat      = loc.latitude
//                    lastLon      = loc.longitude
//                    lastAccuracy = loc.accuracy
//                    lastSpeed    = loc.speed
//                    lastHeartbeatTime = System.currentTimeMillis()
//                    if (loc.isFromMockProvider) checkAndReportFakeGps(loc)
//                }
//                @Deprecated("Deprecated")
//                override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
//                override fun onProviderEnabled(p: String) {}
//                override fun onProviderDisabled(p: String) {}
//            }
//
//            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).forEach { p ->
//                try {
//                    if (locationManager?.isProviderEnabled(p) == true) {
//                        locationManager?.requestLocationUpdates(
//                            p, 4000L, 0f, locationListener!!, Looper.getMainLooper()
//                        )
//                    }
//                } catch (_: Exception) {}
//            }
//        } catch (_: Exception) {}
//    }
//
//    private fun stopLocationUpdates() {
//        try { locationListener?.let { locationManager?.removeUpdates(it) } } catch (_: Exception) {}
//        locationListener = null
//    }
//
//    private fun connectMqtt() {
//        if (isMqttConnected || isConnecting || !isNetworkAvailable()) return
//
//        isConnecting = true
//
//        // Safety timeout — reset isConnecting after 15s
//        handler.postDelayed({
//            if (isConnecting && !isMqttConnected && !isDestroyed) {
//                isConnecting = false
//                safeCloseClient()
//            }
//        }, 15_000L)
//
//        try {
//            val clientId = "android_bg_${System.currentTimeMillis()}"
//            android.util.Log.d("LocationMonitor",
//                "Connecting tcp://$MQTT_HOST:$MQTT_PORT id=$clientId topic=$mqttTopic")
//
//            safeCloseClient()
//
//            mqttClient = MqttAsyncClient(
//                "tcp://$MQTT_HOST:$MQTT_PORT", clientId, MemoryPersistence()
//            )
//
//            mqttClient?.setCallback(object : MqttCallback {
//                override fun connectionLost(cause: Throwable?) {
//                    isMqttConnected = false
//                    isConnecting    = false
//                    android.util.Log.d("LocationMonitor", "Connection lost: ${cause?.message}")
//                    // Watchdog handles reconnection
//                }
//                override fun messageArrived(topic: String?, message: MqttMessage?) {}
//                override fun deliveryComplete(token: IMqttDeliveryToken?) {}
//            })
//
//            // FIX #5: keepAlive = 30 to match Dart client
//            val opts = MqttConnectOptions().apply {
//                isCleanSession       = true
//                keepAliveInterval    = 30
//                connectionTimeout    = 15
//                isAutomaticReconnect = false
//            }
//
//            mqttClient?.connect(opts, null, object : IMqttActionListener {
//                override fun onSuccess(asyncActionToken: IMqttToken?) {
//                    isMqttConnected   = true
//                    isConnecting      = false
//                    lastHeartbeatTime = System.currentTimeMillis()
//                    android.util.Log.d("LocationMonitor", "✅ MQTT Connected! topic=$mqttTopic")
//                    updateNotification("Online | GPS → $mqttTopic", false)
//                }
//                override fun onFailure(asyncActionToken: IMqttToken?, exception: Throwable?) {
//                    isMqttConnected = false
//                    isConnecting    = false
//                    android.util.Log.d("LocationMonitor", "Connect failed: ${exception?.message}")
//                }
//            })
//        } catch (e: Exception) {
//            isMqttConnected = false
//            isConnecting    = false
//        }
//    }
//
//    private fun publishLocationViaMqtt() {
//        if (!isMqttConnected || (lastLat == 0.0 && lastLon == 0.0)) return
//        try {
//            val payload = buildPayload()
//            val msg     = MqttMessage(payload.toByteArray(Charsets.UTF_8))
//            msg.qos     = 1
//            mqttClient?.publish(mqttTopic, msg)
//            lastHeartbeatTime = System.currentTimeMillis()
//        } catch (e: Exception) {
//            isMqttConnected = false
//        }
//    }
//
//    private fun buildPayload(): String {
//        val ts = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).format(Date())
//        return JSONObject().apply {
//            put("device_id",    deviceId)
//            put("company_code", companyCode)
//            put("emp_name",     empName)
//            put("track_id",     System.currentTimeMillis())
//            put("lat",          lastLat)
//            put("lon",          lastLon)
//            put("accuracy",     lastAccuracy.toDouble())
//            put("speed",        lastSpeed.toDouble())
//            put("timestamp",    ts)
//            put("source",       "android_background_service")
//        }.toString()
//    }
//
//    private fun postLocationToApi() {
//        try {
//            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            val empIdKeys = listOf(
//                "flutter.emp_id", "emp_id", "flutter.empId", "empId",
//                "flutter.user_id", "user_id", "flutter.userId", "userId"
//            )
//            var empId = ""
//            for (key in empIdKeys) {
//                val value = prefString(prefs, key)
//                if (value.isNotEmpty()) { empId = value; break }
//            }
//            if (empId.isEmpty()) {
//                try {
//                    for ((key, raw) in prefs.all) {
//                        if (key.contains("emp_id", true) || key.contains("empId", true) ||
//                            key.contains("user_id", true) || key.contains("userId", true)) {
//                            val candidate = raw?.toString()?.trim() ?: ""
//                            if (candidate.isNotEmpty() && candidate != "null") {
//                                empId = candidate; break
//                            }
//                        }
//                    }
//                } catch (_: Exception) {}
//            }
//            if (empId.isEmpty()) return
//
//            var lat = lastLat; var lon = lastLon
//            if (lat == 0.0 && lon == 0.0) {
//                try {
//                    val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
//                    for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)) {
//                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
//                            val loc = lm.getLastKnownLocation(p)
//                            if (loc != null) { lat = loc.latitude; lon = loc.longitude; break }
//                        }
//                    }
//                } catch (_: Exception) {}
//            }
//            if (lat == 0.0 && lon == 0.0) return
//
//            var name = empName.ifEmpty { prefString(prefs, "flutter.emp_name").ifEmpty { prefString(prefs, "emp_name") } }
//            var company = companyCode.ifEmpty { prefString(prefs, "flutter.company_code").ifEmpty { prefString(prefs, "company_code") } }
//
//            val snapLat = lat; val snapLon = lon; val snapEmp = empId; val snapName = name; val snapCo = company
//
//            Thread {
//                try {
//                    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
//                    val battery = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).coerceIn(0, 100)
//
//                    var address = ""
//                    try {
//                        @Suppress("DEPRECATION")
//                        val results = Geocoder(applicationContext, JavaLocale.getDefault()).getFromLocation(snapLat, snapLon, 1)
//                        if (!results.isNullOrEmpty()) {
//                            val a = results[0]
//                            address = listOfNotNull(a.thoroughfare, a.subLocality, a.locality, a.adminArea, a.countryName)
//                                .filter { it.isNotEmpty() }.joinToString(", ")
//                        }
//                    } catch (_: Exception) {}
//
//                    val trackDate = SimpleDateFormat("dd-MM-yyyy HH:mm:ss", Locale.getDefault()).format(Date())
//                    val json = JSONObject().apply {
//                        put("lat", snapLat); put("lng", snapLon); put("emp_id", snapEmp)
//                        put("emp_name", snapName); put("company_code", snapCo)
//                        put("track_date", trackDate); put("battery_percent", battery); put("address", address)
//                    }.toString()
//
//                    val conn = (URL(HTTP_POST_URL).openConnection() as HttpURLConnection).apply {
//                        requestMethod = "POST"
//                        setRequestProperty("Content-Type", "application/json")
//                        setRequestProperty("Accept", "application/json")
//                        doOutput = true; connectTimeout = 15000; readTimeout = 15000
//                    }
//                    OutputStreamWriter(conn.outputStream).use { it.write(json) }
//                    conn.responseCode
//                    conn.disconnect()
//                } catch (_: Exception) {}
//            }.start()
//        } catch (_: Exception) {}
//    }
//
//    private fun checkAndReportFakeGps(loc: Location) {
//        val now = System.currentTimeMillis()
//        if (now - lastFakeGpsReportTime < FAKE_GPS_COOLDOWN_MS) return
//        lastFakeGpsReportTime = now
//
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val empId = prefString(prefs, "emp_id")
//        val detectedAt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())
//        val json = JSONObject().apply {
//            put("emp_id", empId); put("emp_name", empName); put("company_code", companyCode)
//            put("latitude", loc.latitude); put("longitude", loc.longitude); put("detected_at", detectedAt)
//        }.toString()
//
//        Thread {
//            try {
//                val conn = (URL(FAKE_GPS_API).openConnection() as HttpURLConnection).apply {
//                    requestMethod = "POST"; setRequestProperty("Content-Type", "application/json")
//                    doOutput = true; connectTimeout = 10_000; readTimeout = 10_000
//                }
//                OutputStreamWriter(conn.outputStream).use { it.write(json) }
//                conn.responseCode; conn.disconnect()
//            } catch (_: Exception) {}
//        }.start()
//    }
//
//    private fun disconnectMqtt() {
//        try { if (mqttClient?.isConnected == true) mqttClient?.disconnect() } catch (_: Exception) {}
//        isMqttConnected = false
//        safeCloseClient()
//    }
//
//    private fun safeCloseClient() {
//        try { mqttClient?.close() } catch (_: Exception) {}
//        mqttClient = null
//    }
//
//    private fun isNetworkAvailable(): Boolean {
//        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
//        val nw = cm.activeNetwork ?: return false
//        val nc = cm.getNetworkCapabilities(nw) ?: return false
//        return nc.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
//    }
//
//    // FIX #3: Network callback ONLY triggers MQTT reconnect
//    // Previously it called handler.removeCallbacksAndMessages(null) which
//    // killed ALL runnables — watchdog, heartbeat, GPS publish, HTTP post
//    private fun registerNetworkCallback() {
//        try {
//            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
//            val request = NetworkRequest.Builder()
//                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
//                .build()
//            networkCallback = object : ConnectivityManager.NetworkCallback() {
//                override fun onAvailable(network: Network) {
//                    android.util.Log.d("LocationMonitor", "✅ Network available — reconnecting MQTT")
//                    handler.post {
//                        if (!isMqttConnected && !isConnecting && !isDestroyed) {
//                            connectMqtt()
//                        }
//                    }
//                }
//                override fun onLost(network: Network) {
//                    isMqttConnected = false
//                    isConnecting = false
//                }
//            }
//            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
//        } catch (_: Exception) {}
//    }
//
//    private fun unregisterNetworkCallback() {
//        try { networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) } } catch (_: Exception) {}
//        networkCallback = null
//    }
//
//    private fun registerAppOpsListener() {
//        try {
//            appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
//            val listener = AppOpsManager.OnOpChangedListener { _, pkg ->
//                if (pkg == packageName) handler.post { checkLocationAndPermission() }
//            }
//            appOpsManager?.startWatchingMode(AppOpsManager.OPSTR_FINE_LOCATION, packageName, listener)
//            appOpsCallback = listener
//        } catch (_: Exception) {}
//    }
//
//    private fun unregisterAppOpsListener() {
//        try { appOpsCallback?.let { appOpsManager?.stopWatchingMode(it) }; appOpsCallback = null } catch (_: Exception) {}
//    }
//
//    private fun registerReceivers() {
//        val locationModeReceiver = object : BroadcastReceiver() {
//            override fun onReceive(context: Context?, intent: Intent?) {
//                if (intent?.action == LocationManager.MODE_CHANGED_ACTION) {
//                    handler.post { checkLocationAndPermission() }
//                }
//            }
//        }
//        registerReceiver(locationModeReceiver, IntentFilter(LocationManager.MODE_CHANGED_ACTION))
//    }
//
//    private fun createNotificationChannel() {
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//            val serviceChannel = NotificationChannel(CHANNEL_ID, "Location Monitor Service", NotificationManager.IMPORTANCE_LOW)
//                .apply { description = "Monitors location + MQTT GPS publishing" }
//            val urgentChannel = NotificationChannel(URGENT_CHANNEL_ID, "URGENT Auto Clockout", NotificationManager.IMPORTANCE_HIGH)
//                .apply { description = "Critical auto clockout notifications"; enableVibration(true); enableLights(true); lightColor = android.graphics.Color.RED }
//            val manager = getSystemService(NotificationManager::class.java)
//            manager.createNotificationChannel(serviceChannel)
//            manager.createNotificationChannel(urgentChannel)
//        }
//    }
//
//    private fun buildNotification(text: String): Notification {
//        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
//        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE)
//        return NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle("Attendance Active").setContentText(text)
//            .setSmallIcon(android.R.drawable.ic_dialog_info)
//            .setContentIntent(pendingIntent).setOngoing(true).setSilent(true).build()
//    }
//
//    private fun updateNotification(text: String, isAlert: Boolean) {
//        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
//        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
//        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle(if (isAlert) "⚠️ ATTENTION REQUIRED" else "Attendance Active")
//            .setContentText(text).setSmallIcon(android.R.drawable.ic_dialog_info)
//            .setContentIntent(pendingIntent).setOngoing(true).setSilent(!isAlert)
//            .apply { if (isAlert) { setColor(android.graphics.Color.RED); setLights(android.graphics.Color.RED, 1000, 500) } }
//            .build()
//        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
//    }
//
//    private fun showCriticalNotification(reason: String, time: String) {
//        val title = when (reason) {
//            "System Clockout - Location Off"       -> "⚠️ LOCATION TURNED OFF"
//            "permission_revoked_auto" -> "⚠️ PERMISSION REVOKED"
//            "System Clockout - Midnight Time"           -> "⚠️ MIDNIGHT AUTO CLOCKOUT"
//            "System Clockout - Shift End"          -> "⏰ SHIFT END AUTO CLOCKOUT"
//            else                      -> "⚠️ AUTO CLOCKOUT"
//        }
//        val message = "Time: $time\nApp was closed - Event captured. Open app to sync."
//        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
//            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//        }
//        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
//        val notification = NotificationCompat.Builder(this, URGENT_CHANNEL_ID)
//            .setContentTitle(title).setContentText(message).setSmallIcon(android.R.drawable.ic_dialog_alert)
//            .setPriority(NotificationCompat.PRIORITY_MAX).setCategory(NotificationCompat.CATEGORY_ALARM)
//            .setAutoCancel(true).setContentIntent(pendingIntent)
//            .setVibrate(longArrayOf(0, 1000, 500, 1000)).setLights(android.graphics.Color.RED, 1000, 500)
//            .build()
//        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(9999, notification)
//    }
//
//    private fun isLocationEnabled(): Boolean {
//        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
//            (getSystemService(Context.LOCATION_SERVICE) as LocationManager).isLocationEnabled
//        } else {
//            try {
//                Settings.Secure.getInt(contentResolver, Settings.Secure.LOCATION_MODE, Settings.Secure.LOCATION_MODE_OFF) != Settings.Secure.LOCATION_MODE_OFF
//            } catch (_: Exception) { false }
//        }
//    }
//
//    private fun checkLocationPermission(): Boolean {
//        return try {
//            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
//                    ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
//        } catch (_: Exception) { false }
//    }
//
//    override fun onBind(intent: Intent?): IBinder? = null
//
//    override fun onTaskRemoved(rootIntent: Intent?) {
//        super.onTaskRemoved(rootIntent)
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val frozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        if (clocked && !frozen) {
//            val restartIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
//                putExtra(EXTRA_DEVICE_ID, deviceId)
//                putExtra(EXTRA_COMPANY_CODE, companyCode)
//                putExtra(EXTRA_EMP_NAME, empName)
//            }
//            val pi = PendingIntent.getService(applicationContext, 1, restartIntent, PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE)
//            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
//            val triggerTime = android.os.SystemClock.elapsedRealtime() + 1000L
//
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
//                alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi)
//            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
//                alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi)
//            } else {
//                alarmManager.set(AlarmManager.ELAPSED_REALTIME, triggerTime, pi)
//            }
//        }
//    }
//
//    override fun onDestroy() {
//        isDestroyed = true
//        handler.removeCallbacks(checkRunnable)
//        handler.removeCallbacks(gpsRunnable)
//        httpPostRunnable?.let { handler.removeCallbacks(it) }
//        watchdogRunnable?.let { handler.removeCallbacks(it) }
//        heartbeatRunnable?.let { handler.removeCallbacks(it) }
//
//        // ── PERMISSION-REVOKED AUTO CLOCKOUT ───────────────────────────────
//        // Jab Android App Info se location permission revoke hoti hai, OS
//        // service ko forcibly destroy kar deta hai.  checkLocationAndPermission()
//        // us waqt run nahi hota, isliye yahan check karo:
//        // Agar user clocked-in tha AUR permission ab nahi hai AUR timer abhi
//        // frozen nahi tha → critical event save karo taake Flutter app khulne
//        // par auto-clockout reason dikh sake.
//        try {
//            val prefs    = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//            val clocked  = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//            val frozen   = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//            val permNow  = checkLocationPermission()   // will return false if revoked
//            if (clocked && !frozen && !permNow) {
//                handleCriticalEvent("permission_revoked_auto")
//                android.util.Log.d("LocationMonitor",
//                    "onDestroy: permission revoked while clocked-in → auto clockout saved")
//            }
//        } catch (e: Exception) {
//            android.util.Log.e("LocationMonitor", "onDestroy permission-check error: ${e.message}")
//        }
//        // ──────────────────────────────────────────────────────────────────
//
//        stopLocationUpdates()
//        disconnectMqtt()
//        unregisterNetworkCallback()
//        unregisterAppOpsListener()
//
//        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
//
//        super.onDestroy()
//    }
//}
// ============================================================
//  LocationMonitorService.kt — BACKGROUND MQTT FIX
//
//  BUGS FIXED:
//    1. Identity (deviceId/companyCode/empName) now persisted to
//       SharedPreferences so boot/restart recovers them
//    2. PARTIAL_WAKE_LOCK replaces deprecated FULL_WAKE_LOCK
//    3. Network callback no longer nukes all handler runnables
//    4. Removed screen wake lock cycling (caused OEM battery kill)
//    5. MQTT keepAlive = 30 to match Dart client
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

import org.eclipse.paho.client.mqttv3.IMqttActionListener
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken
import org.eclipse.paho.client.mqttv3.IMqttToken
import org.eclipse.paho.client.mqttv3.MqttAsyncClient
import org.eclipse.paho.client.mqttv3.MqttCallback
import org.eclipse.paho.client.mqttv3.MqttConnectOptions
import org.eclipse.paho.client.mqttv3.MqttMessage
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence

import org.json.JSONObject

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
    private val CHANNEL_ID        = "location_monitor_channel"
    private val URGENT_CHANNEL_ID = "urgent_auto_clockout_channel"
    private val NOTIFICATION_ID   = 1001
    private val CHECK_INTERVAL    = 2000L
    private val GPS_PUBLISH_MS    = 5000L

    private val HTTP_POST_MS  = 2 * 60 * 1000L
    private val HTTP_POST_URL = "http://oracle.metaxperts.net/ords/gps_workforce/emplocation/post/"

    private val MQTT_HOST = "103.149.33.102"
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
    private var isDestroyed = false

    // FIX #2: PARTIAL_WAKE_LOCK — the ONLY type that prevents CPU sleep
    private var wakeLock: android.os.PowerManager.WakeLock? = null

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

    override fun onCreate() {
        super.onCreate()
        handler = Handler(Looper.getMainLooper())

        // FIX #2: PARTIAL_WAKE_LOCK keeps CPU running even when screen is off
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

        // FIX #1: Read identity from Intent extras first, fall back to prefs
        deviceId    = intent?.getStringExtra(EXTRA_DEVICE_ID)?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "user_name")
        companyCode = intent?.getStringExtra(EXTRA_COMPANY_CODE)?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "company_code")
        empName     = intent?.getStringExtra(EXTRA_EMP_NAME)?.takeIf { it.isNotEmpty() }
            ?: prefString(prefs, "emp_name")

        // Read dept_id and emp_image from login-cached SharedPreferences
        depId    = prefString(prefs, "flutter.cached_dep_id")
        empImage = prefString(prefs, "flutter.cached_image_url")

        // FIX #1b: Persist identity so boot receiver / alarm restart can recover
        prefs.edit().apply {
            if (deviceId.isNotEmpty())    putString("user_name",    deviceId)
            if (companyCode.isNotEmpty()) putString("company_code", companyCode)
            if (empName.isNotEmpty())     putString("emp_name",     empName)
            apply()
        }

        android.util.Log.d("LocationMonitor",
            "identity → deviceId=$deviceId  company=$companyCode  emp=$empName  topic=$mqttTopic")

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
                handler.postDelayed({ handleCriticalEvent("System Clockout - Permission Revoked") }, 500)
                return START_STICKY
            }
            if (!wasLocationEnabled) {
                handler.postDelayed({ handleCriticalEvent("System Clockout - Location Off") }, 500)
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

        startMqttWatchdog()
        startHeartbeatWatchdog()
    }

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
                lastEventReason = "System Clockout - Midnight Time"
                handleCriticalEvent("System Clockout - Midnight Time")
                return
            }
        }

        val cachedEndTime = prefString(prefs, "flutter.cached_end_time")
        if (cachedEndTime.isNotEmpty()) {
            try {
                val overtime = prefString(prefs, "flutter.cached_overtime").lowercase()
                val overtimeAllowed = overtime == "yes" || overtime == "y" || overtime == "true"
                if (!overtimeAllowed) {
                    val parsed = parseTimeTo24h(cachedEndTime)
                    if (parsed != null) {
                        val endTotalMin = parsed.first * 60 + parsed.second
                        val nowTotalMin = hour * 60 + minute
                        val diffMin     = nowTotalMin - endTotalMin
                        if (diffMin in 0..480) {
                            val currentTime = System.currentTimeMillis()
                            if (currentTime - lastEventTime > 60000 && lastEventReason != "System Clockout - Shift End") {
                                lastEventTime   = currentTime
                                lastEventReason = "System Clockout - Shift End"
                                handleCriticalEvent("System Clockout - Shift End")
                                return
                            }
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
            "Monitoring - All OK | MQTT: ${if (isMqttConnected) "●" else "○"}"
        } else {
            "Issue detected - Processing..."
        }
        updateNotification(status, false)
    }

    private fun handleCriticalEvent(reason: String) {
        val prefs         = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alreadyFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
        if (alreadyFrozen) return

        val editor    = prefs.edit()
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())

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
        val fastJson = """{"fast_attendanceId":"","fast_userId":"","fast_clockOutTime":"$timestamp","fast_totalTime":"00:00:00","fast_totalDistance":0.0,"fast_reason":"$reason","fast_clockInTime":"$clockInTime"}"""
        editor.putString("flutter.fastClockOutData", fastJson)

        try { editor.commit() } catch (e: Exception) { editor.apply() }

        showCriticalNotification(reason, timestamp)
        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)

        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        httpPostRunnable?.let { handler.removeCallbacks(it) }
        watchdogRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable?.let { handler.removeCallbacks(it) }

        disconnectMqtt()

        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (_: Exception) {}
        stopSelf()
    }

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
                            p, 4000L, 0f, locationListener!!, Looper.getMainLooper()
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

    private fun connectMqtt() {
        if (isMqttConnected || isConnecting || !isNetworkAvailable()) return

        isConnecting = true

        // Safety timeout — reset isConnecting after 15s
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
                    // Watchdog handles reconnection
                }
                override fun messageArrived(topic: String?, message: MqttMessage?) {}
                override fun deliveryComplete(token: IMqttDeliveryToken?) {}
            })

            // FIX #5: keepAlive = 30 to match Dart client
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

            var name = empName.ifEmpty { prefString(prefs, "flutter.emp_name").ifEmpty { prefString(prefs, "emp_name") } }
            var company = companyCode.ifEmpty { prefString(prefs, "flutter.company_code").ifEmpty { prefString(prefs, "company_code") } }

            val snapLat = lat; val snapLon = lon; val snapEmp = empId; val snapName = name; val snapCo = company

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

    // FIX #3: Network callback ONLY triggers MQTT reconnect
    // Previously it called handler.removeCallbacksAndMessages(null) which
    // killed ALL runnables — watchdog, heartbeat, GPS publish, HTTP post
    private fun registerNetworkCallback() {
        try {
            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    android.util.Log.d("LocationMonitor", "✅ Network available — reconnecting MQTT")
                    handler.post {
                        if (!isMqttConnected && !isConnecting && !isDestroyed) {
                            connectMqtt()
                        }
                    }
                }
                override fun onLost(network: Network) {
                    isMqttConnected = false
                    isConnecting = false
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
        val locationModeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == LocationManager.MODE_CHANGED_ACTION) {
                    handler.post { checkLocationAndPermission() }
                }
            }
        }
        registerReceiver(locationModeReceiver, IntentFilter(LocationManager.MODE_CHANGED_ACTION))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(CHANNEL_ID, "Location Monitor Service", NotificationManager.IMPORTANCE_LOW)
                .apply { description = "Monitors location + MQTT GPS publishing" }
            val urgentChannel = NotificationChannel(URGENT_CHANNEL_ID, "URGENT Auto Clockout", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "Critical auto clockout notifications"; enableVibration(true); enableLights(true); lightColor = android.graphics.Color.RED }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
            manager.createNotificationChannel(urgentChannel)
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
        val title = when (reason) {
            "System Clockout - Location Off"       -> "⚠️ LOCATION TURNED OFF"
            "System Clockout - Permission Revoked" -> "⚠️ PERMISSION REVOKED"
            "System Clockout - Midnight Time"           -> "⚠️ MIDNIGHT AUTO CLOCKOUT"
            "System Clockout - Shift End"          -> "⏰ SHIFT END AUTO CLOCKOUT"
            else                      -> "⚠️ AUTO CLOCKOUT"
        }
        val message = "Time: $time\nApp was closed - Event captured. Open app to sync."
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = NotificationCompat.Builder(this, URGENT_CHANNEL_ID)
            .setContentTitle(title).setContentText(message).setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX).setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true).setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 1000, 500, 1000)).setLights(android.graphics.Color.RED, 1000, 500)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(9999, notification)
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
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clocked = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val frozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clocked && !frozen) {
            val restartIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
                putExtra(EXTRA_DEVICE_ID, deviceId)
                putExtra(EXTRA_COMPANY_CODE, companyCode)
                putExtra(EXTRA_EMP_NAME, empName)
            }
            val pi = PendingIntent.getService(applicationContext, 1, restartIntent, PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE)
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerTime = android.os.SystemClock.elapsedRealtime() + 1000L

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerTime, pi)
            } else {
                alarmManager.set(AlarmManager.ELAPSED_REALTIME, triggerTime, pi)
            }
        }
    }

    override fun onDestroy() {
        isDestroyed = true
        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        httpPostRunnable?.let { handler.removeCallbacks(it) }
        watchdogRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable?.let { handler.removeCallbacks(it) }

        // ── PERMISSION-REVOKED AUTO CLOCKOUT ───────────────────────────────
        // Jab Android App Info se location permission revoke hoti hai, OS
        // service ko forcibly destroy kar deta hai.  checkLocationAndPermission()
        // us waqt run nahi hota, isliye yahan check karo:
        // Agar user clocked-in tha AUR permission ab nahi hai AUR timer abhi
        // frozen nahi tha → critical event save karo taake Flutter app khulne
        // par auto-clockout reason dikh sake.
        try {
            val prefs    = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val clocked  = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
            val frozen   = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
            val permNow  = checkLocationPermission()   // will return false if revoked
            if (clocked && !frozen && !permNow) {
                handleCriticalEvent("System Clockout - Permission Revoked")
                android.util.Log.d("LocationMonitor",
                    "onDestroy: permission revoked while clocked-in → auto clockout saved")
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationMonitor", "onDestroy permission-check error: ${e.message}")
        }
        // ──────────────────────────────────────────────────────────────────

        stopLocationUpdates()
        disconnectMqtt()
        unregisterNetworkCallback()
        unregisterAppOpsListener()

        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}

        super.onDestroy()
    }
}