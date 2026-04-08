
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

// ✅ Fake GPS — HTTP POST
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LocationMonitorService : Service() {
    private val CHANNEL_ID        = "location_monitor_channel"
    private val URGENT_CHANNEL_ID = "urgent_auto_clockout_channel"
    private val NOTIFICATION_ID   = 1001
    private val CHECK_INTERVAL    = 2000L
    private val GPS_PUBLISH_MS    = 5000L

    // MQTT broker
    private val MQTT_HOST = "103.149.33.102"
    private val MQTT_PORT = 1883

    // ✅ UPDATED: Dynamic topic — set once identity is known
    // Topic format: gps/{companyCode}/{deviceId}
    private val mqttTopic get() = "gps/$companyCode/$deviceId"

    // SharedPreferences keys
    private val PREFS_NAME              = "FlutterSharedPreferences"
    private val KEY_IS_CLOCKED_IN       = "flutter.isClockedIn"
    private val KEY_HAS_CRITICAL_EVENT  = "flutter.has_critical_event_pending"
    private val KEY_EVENT_TIMESTAMP     = "flutter.critical_event_timestamp"
    private val KEY_EVENT_REASON        = "flutter.critical_event_reason"
    private val KEY_IS_TIMER_FROZEN     = "flutter.is_timer_frozen"
    private val KEY_ELAPSED_TIME        = "flutter.elapsed_time"

    private lateinit var handler: Handler
    private lateinit var checkRunnable: Runnable
    private lateinit var gpsRunnable: Runnable

    private var wasLocationEnabled   = true
    private var wasPermissionGranted = true
    private var isClockedIn          = false
    private var lastEventTime: Long  = 0
    private var lastEventReason: String = ""
    private var serviceStartTime: Date  = Date()

    // Location
    private var lastLat       = 0.0
    private var lastLon       = 0.0
    private var lastAccuracy  = 0f
    private var lastSpeed     = 0f
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

    // ✅ NEW: Identity — set from Intent extras on fresh start,
    //         or from SharedPreferences when OS restarts the service.
    private var deviceId    = ""
    private var companyCode = ""
    private var empName     = ""

    // ✅ Fake GPS detection
    private val FAKE_GPS_API            = "http://oracle.metaxperts.net/ords/gps_workforce/fakegps/post/"
    private var lastFakeGpsReportTime: Long = 0
    private val FAKE_GPS_COOLDOWN_MS    = 30_000L

    companion object {
        // Intent extra keys — must match MainActivity and mqtt_work.dart
        const val EXTRA_DEVICE_ID    = "deviceId"
        const val EXTRA_COMPANY_CODE = "companyCode"
        const val EXTRA_EMP_NAME     = "empName"

        /** Start the service without identity extras (monitoring-only restart). */
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

        /** ✅ NEW: Start with identity extras so the correct MQTT topic is used. */
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

    override fun onCreate() {
        super.onCreate()
        handler = Handler(Looper.getMainLooper())
        registerReceivers()
        registerNetworkCallback()
        registerAppOpsListener()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        serviceStartTime = Date()

        // ✅ UPDATED: Read identity from Intent extras first.
        //             If the OS restarted the service (intent == null / no extras),
        //             fall back to what Flutter last wrote in SharedPreferences.
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        deviceId    = intent?.getStringExtra(EXTRA_DEVICE_ID)   ?.takeIf { it.isNotEmpty() }
            ?: prefs.getString("flutter.user_name",     "") ?: ""
        companyCode = intent?.getStringExtra(EXTRA_COMPANY_CODE)?.takeIf { it.isNotEmpty() }
            ?: prefs.getString("flutter.company_code",  "") ?: ""
        empName     = intent?.getStringExtra(EXTRA_EMP_NAME)    ?.takeIf { it.isNotEmpty() }
            ?: prefs.getString("flutter.emp_name",      "") ?: ""

        debugPrint("identity → deviceId=$deviceId  company=$companyCode  emp=$empName  topic=$mqttTopic")

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
            debugPrint("startForeground failed: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        wasLocationEnabled   = isLocationEnabled()
        wasPermissionGranted = checkLocationPermission()

        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen  = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clockedIn && !isFrozen) {
            if (!wasPermissionGranted) {
                debugPrint("🔐 Service restarted — permission REVOKED!")
                handler.postDelayed({ handleCriticalEvent("permission_revoked_auto") }, 500)
                return START_STICKY
            }
            if (!wasLocationEnabled) {
                debugPrint("📍 Service restarted — location OFF!")
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

        // Midnight check
        val calendar = java.util.Calendar.getInstance()
        val hour   = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val minute = calendar.get(java.util.Calendar.MINUTE)

        if (hour == 23 && minute == 58) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 60000) {
                lastEventTime  = currentTime
                lastEventReason = "midnight_auto"
                debugPrint("⏰ Midnight detected → handleCriticalEvent")
                handleCriticalEvent("midnight_auto")
                return
            }
        }

        val currentLocationEnabled  = isLocationEnabled()
        val currentPermissionGranted = checkLocationPermission()

        if (wasPermissionGranted && !currentPermissionGranted) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 5000 && lastEventReason != "permission_revoked_auto") {
                lastEventTime   = currentTime
                lastEventReason = "permission_revoked_auto"
                debugPrint("🔐 Permission REVOKED → handleCriticalEvent")
                handleCriticalEvent("permission_revoked_auto")
                return
            }
        }

        if (wasLocationEnabled && !currentLocationEnabled) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 5000 && lastEventReason != "location_off_auto") {
                lastEventTime   = currentTime
                lastEventReason = "location_off_auto"
                debugPrint("📍 Location OFF → handleCriticalEvent")
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
        val prefs        = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alreadyFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (alreadyFrozen) {
            debugPrint("⚠️ Already frozen, skipping duplicate event: $reason")
            return
        }

        val editor    = prefs.edit()
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(serviceStartTime)

        editor.putBoolean(KEY_HAS_CRITICAL_EVENT, true)
        editor.putBoolean(KEY_IS_TIMER_FROZEN,    true)
        editor.putString(KEY_EVENT_TIMESTAMP,     timestamp)
        editor.putString(KEY_EVENT_REASON,        reason)
        editor.putBoolean(KEY_IS_CLOCKED_IN,      false)
        editor.putBoolean("flutter.pending_gpx_close", true)

        editor.putString("flutter.fastClockOutTime",    timestamp)
        editor.putFloat("flutter.fastClockOutDistance",  0.0f)
        editor.putString("flutter.fastClockOutReason",  reason)
        editor.putBoolean("flutter.hasFastClockOutData", true)
        editor.putBoolean("flutter.clockOutPending",     true)

        val clockInTime = prefs.getString("flutter.clockInTime", "") ?: ""
        val fastJson    = """{"fast_attendanceId":"","fast_userId":"","fast_clockOutTime":"$timestamp","fast_totalTime":"00:00:00","fast_totalDistance":0.0,"fast_reason":"$reason","fast_clockInTime":"$clockInTime"}"""
        editor.putString("flutter.fastClockOutData", fastJson)

        try { editor.commit() } catch (e: Exception) { editor.apply() }

        debugPrint("💾 Critical event committed: $reason at $timestamp")
        showCriticalNotification(reason, timestamp)
        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)

        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        disconnectMqtt()

        try { stopForeground(STOP_FOREGROUND_REMOVE) } catch (e: Exception) {}
        stopSelf()
    }

    // ================================================================== //
    //  Location Updates
    // ================================================================== //

    private fun startLocationUpdates() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            debugPrint("No location permission")
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

                    // ✅ Fake GPS detection on every location update
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
                        debugPrint("GPS registered: $p")
                    }
                } catch (e: Exception) {
                    debugPrint("GPS register failed $p: ${e.message}")
                }
            }
        } catch (e: Exception) {
            debugPrint("startLocationUpdates: ${e.message}")
        }
    }

    private fun stopLocationUpdates() {
        try { locationListener?.let { locationManager?.removeUpdates(it) } } catch (_: Exception) {}
        locationListener = null
    }

    // ================================================================== //
    //  MQTT
    // ================================================================== //

    private fun connectMqtt() {
        if (isMqttConnected || isConnecting) return
        if (!isNetworkAvailable()) {
            debugPrint("No network — will retry when network returns")
            return
        }

        isConnecting = true
        try {
            val clientId = "android_bg_${System.currentTimeMillis()}"
            debugPrint("Connecting to tcp://$MQTT_HOST:$MQTT_PORT id=$clientId  topic=$mqttTopic")

            safeCloseClient()

            mqttClient = MqttAsyncClient(
                "tcp://$MQTT_HOST:$MQTT_PORT", clientId, MemoryPersistence()
            )

            mqttClient?.setCallback(object : MqttCallback {
                override fun connectionLost(cause: Throwable?) {
                    isMqttConnected = false
                    isConnecting    = false
                    debugPrint("Connection lost: ${cause?.message}")
                    handler.postDelayed({ connectMqtt() }, 3000L)
                }
                override fun messageArrived(topic: String?, message: MqttMessage?) {}
                override fun deliveryComplete(token: IMqttDeliveryToken?) {}
            })

            // ✅ UPDATED: isCleanSession = false (persist session), keepAlive = 60 s
            val opts = MqttConnectOptions().apply {
                isCleanSession    = false
                keepAliveInterval = 60
                connectionTimeout = 10
                isAutomaticReconnect = false   // we handle reconnect manually via handler
            }

            mqttClient?.connect(opts, null, object : IMqttActionListener {
                override fun onSuccess(asyncActionToken: IMqttToken?) {
                    isMqttConnected = true
                    isConnecting    = false
                    debugPrint("✅ MQTT Connected! topic=$mqttTopic")
                    updateNotification("Online | GPS publishing → $mqttTopic", false)
                }
                override fun onFailure(asyncActionToken: IMqttToken?, exception: Throwable?) {
                    isMqttConnected = false
                    isConnecting    = false
                    debugPrint("Connect failed: ${exception?.message}")
                    // Retry after 5 seconds
                    handler.postDelayed({ connectMqtt() }, 5000L)
                }
            })
        } catch (e: Exception) {
            isMqttConnected = false
            isConnecting    = false
            debugPrint("Exception in connectMqtt: ${e.message}")
        }
    }

    private fun publishLocationViaMqtt() {
        if (!isMqttConnected || (lastLat == 0.0 && lastLon == 0.0)) return
        try {
            val payload = buildPayload()
            val msg     = MqttMessage(payload.toByteArray(Charsets.UTF_8))
            msg.qos = 1
            mqttClient?.publish(mqttTopic, msg)   // ✅ dynamic topic
            debugPrint("📤 Published ✓ lat=$lastLat lon=$lastLon → $mqttTopic")
        } catch (e: Exception) {
            debugPrint("Publish error: ${e.message}")
            isMqttConnected = false
        }
    }

    // ✅ UPDATED: includes company_code and emp_name; uses instance deviceId
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

    // ================================================================== //
    //  Fake GPS Detection
    // ================================================================== //

    private fun checkAndReportFakeGps(loc: Location) {
        val now = System.currentTimeMillis()
        if (now - lastFakeGpsReportTime < FAKE_GPS_COOLDOWN_MS) return
        lastFakeGpsReportTime = now

        debugPrint("🚨 [FakeGPS] Mock location detected! lat=${loc.latitude} lon=${loc.longitude}")

        val prefs2      = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val empId       = prefs2.getString("flutter.emp_id",       "") ?: ""
        val detectedAt  = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())

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
                val url  = URL(FAKE_GPS_API)
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput       = true
                conn.connectTimeout = 10_000
                conn.readTimeout    = 10_000
                OutputStreamWriter(conn.outputStream).use { it.write(json) }
                debugPrint("✅ [FakeGPS] POST → ${conn.responseCode}")
                conn.disconnect()
            } catch (e: Exception) {
                debugPrint("❌ [FakeGPS] POST failed: ${e.message}")
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

    // ================================================================== //
    //  Network Monitoring
    // ================================================================== //

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
                    debugPrint("Network available — reconnecting MQTT")
                    handler.post { connectMqtt() }
                }
                override fun onLost(network: Network) {
                    debugPrint("Network lost")
                    isMqttConnected = false
                }
            }
            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
        } catch (e: Exception) {
            debugPrint("registerNetworkCallback error: ${e.message}")
        }
    }

    private fun unregisterNetworkCallback() {
        try { networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) } } catch (_: Exception) {}
        networkCallback = null
    }

    // ================================================================== //
    //  AppOps Listener (Permission revocation detection)
    // ================================================================== //

    private fun registerAppOpsListener() {
        try {
            appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val listener = AppOpsManager.OnOpChangedListener { _, pkg ->
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
            debugPrint("✅ AppOps listener registered")
        } catch (e: Exception) {
            debugPrint("⚠️ AppOps listener failed: ${e.message}")
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
            debugPrint("Error unregistering: ${e.message}")
        }
    }

    // ================================================================== //
    //  Broadcast Receivers
    // ================================================================== //

    private fun registerReceivers() {
        registerReceiver(locationModeReceiver, IntentFilter(LocationManager.MODE_CHANGED_ACTION))

        val dateTimeFilter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        registerReceiver(dateTimeChangeReceiver, dateTimeFilter)
    }

    private val locationModeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == LocationManager.MODE_CHANGED_ACTION) {
                debugPrint("Location mode changed")
                handler.post { checkLocationAndPermission() }
            }
        }
    }

    private val dateTimeChangeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            if (action in listOf(
                    Intent.ACTION_TIME_CHANGED,
                    Intent.ACTION_DATE_CHANGED,
                    Intent.ACTION_TIMEZONE_CHANGED
                )
            ) {
                val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val clocked   = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                val frozen    = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

                if (clocked && !frozen) {
                    val now = System.currentTimeMillis()
                    if (now - lastEventTime > 5000 && lastEventReason != "time_changed_auto") {
                        lastEventTime   = now
                        lastEventReason = "time_changed_auto"
                        debugPrint("⏰ Date/Time changed")
                        handleCriticalEvent("time_changed_auto")
                    }
                }
            }
        }
    }

    // ================================================================== //
    //  Notifications
    // ================================================================== //

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
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(" Attendance Active")
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
            .setContentTitle(if (isAlert) "⚠️ ATTENTION REQUIRED" else " Attendance Active")
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
            "location_off_auto"      -> "⚠️ LOCATION TURNED OFF"
            "permission_revoked_auto"-> "⚠️ PERMISSION REVOKED"
            "midnight_auto"          -> "⚠️ MIDNIGHT AUTO CLOCKOUT"
            else                     -> "⚠️ AUTO CLOCKOUT"
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

        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(9999, notification)
    }

    // ================================================================== //
    //  Helpers
    // ================================================================== //

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

    private fun debugPrint(message: String) {
        android.util.Log.d("LocationMonitor", message)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        debugPrint("App removed from recents — scheduling service restart")

        val prefs     = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clocked   = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val frozen    = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (clocked && !frozen) {
            // Re-start via AlarmManager so the service survives task removal
            val restartIntent = Intent(applicationContext, LocationMonitorService::class.java).apply {
                putExtra(EXTRA_DEVICE_ID,    deviceId)
                putExtra(EXTRA_COMPANY_CODE, companyCode)
                putExtra(EXTRA_EMP_NAME,     empName)
            }
            val pi = PendingIntent.getService(
                applicationContext, 1, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            (getSystemService(Context.ALARM_SERVICE) as AlarmManager).set(
                AlarmManager.ELAPSED_REALTIME,
                android.os.SystemClock.elapsedRealtime() + 1000,
                pi
            )
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        stopLocationUpdates()
        disconnectMqtt()
        unregisterNetworkCallback()
        unregisterAppOpsListener()
        try {
            unregisterReceiver(locationModeReceiver)
            unregisterReceiver(dateTimeChangeReceiver)
        } catch (e: Exception) {}
        super.onDestroy()
    }
}