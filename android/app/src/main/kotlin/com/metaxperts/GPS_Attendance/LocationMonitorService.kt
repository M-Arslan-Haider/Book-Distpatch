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
//import android.location.LocationManager
//import android.os.Build
//import android.os.Handler
//import android.os.IBinder
//import android.os.Looper
//import android.os.PowerManager
//import android.provider.Settings
//import androidx.core.app.NotificationCompat
//import androidx.core.content.ContextCompat
//import java.text.SimpleDateFormat
//import java.util.Date
//import java.util.Locale
//import android.Manifest
//
//class LocationMonitorService : Service() {
//    private val CHANNEL_ID = "location_monitor_channel"
//    private val URGENT_CHANNEL_ID = "urgent_auto_clockout_channel"
//    private val NOTIFICATION_ID = 1001
//    private val CHECK_INTERVAL = 2000L // 2 seconds
//
//    private lateinit var handler: Handler
//    private lateinit var checkRunnable: Runnable
//    private var wasLocationEnabled = true
//    private var wasPermissionGranted = true
//    private var isClockedIn = false
//
//    // ✅ NEW: Track last critical event to prevent duplicates
//    private var lastEventTime: Long = 0
//    private var lastEventReason: String = ""
//
//    // ✅ NEW: Capture service start time (reference for date/time change detection)
//    private var serviceStartTime: Date = Date()
//
//    // SharedPreferences keys (must match Flutter - note the flutter. prefix)
//    private val PREFS_NAME = "FlutterSharedPreferences"
//    private val KEY_IS_CLOCKED_IN = "flutter.isClockedIn"
//    private val KEY_HAS_CRITICAL_EVENT = "flutter.has_critical_event_pending"
//    private val KEY_EVENT_TIMESTAMP = "flutter.critical_event_timestamp"
//    private val KEY_EVENT_REASON = "flutter.critical_event_reason"
//    private val KEY_EVENT_DISTANCE = "flutter.critical_event_distance"
//    private val KEY_EVENT_LAT = "flutter.critical_event_latitude"
//    private val KEY_EVENT_LNG = "flutter.critical_event_longitude"
//    private val KEY_IS_TIMER_FROZEN = "flutter.is_timer_frozen"
//    private val KEY_FROZEN_TIME = "flutter.frozen_display_time"
//    private val KEY_ELAPSED_TIME = "flutter.elapsed_time"
//
//    // Key for complete background clockout payload (for auto-sync on app open)
//    private val KEY_BG_CLOCKOUT_PAYLOAD = "flutter.bg_clockout_payload"
//
//    // AppOpsManager listener objects (for realtime permission revocation detection)
//    private var appOpsManager: AppOpsManager? = null
//    private var appOpsCallback: AppOpsManager.OnOpChangedListener? = null
//
//    override fun onCreate() {
//        super.onCreate()
//        handler = Handler(Looper.getMainLooper())
//        registerReceivers()
//        registerAppOpsListener()
//    }
//
//    // Register AppOps listener to detect real-time permission revocation (best-effort)
//    private fun registerAppOpsListener() {
//        try {
//            appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
//            val listener = AppOpsManager.OnOpChangedListener { op, pkg ->
//                debugPrint("🔐 [APPOPS] Op changed: op=$op, pkg=$pkg")
//                // We only care about our package changes
//                if (pkg == packageName) {
//                    handler.post { checkPermissionAndHandleRevocation() }
//                } else {
//                    // Even if it's not our package, re-check as a safe fallback
//                    handler.post { checkLocationAndPermission() }
//                }
//            }
//            // Watch FINE_LOCATION op for our package
//            appOpsManager?.startWatchingMode(
//                AppOpsManager.OPSTR_FINE_LOCATION,
//                this@LocationMonitorService.packageName,
//                listener
//            )
//            appOpsCallback = listener
//            debugPrint("✅ [APPOPS] OnOpChangedListener registered for FINE_LOCATION")
//        } catch (e: Exception) {
//            debugPrint("⚠️ [APPOPS] Failed to register AppOps listener: ${e.message}")
//            // Fallbacks (polling + receivers) will still work
//        }
//    }
//
//    private fun unregisterAppOpsListener() {
//        try {
//            val cb = appOpsCallback
//            if (cb != null) {
//                appOpsManager?.stopWatchingMode(cb)
//                appOpsCallback = null
//                debugPrint("🛑 [APPOPS] Listener unregistered")
//            }
//        } catch (e: Exception) {
//            debugPrint("⚠️ [APPOPS] Error unregistering: ${e.message}")
//        }
//    }
//
//    private fun registerReceivers() {
//        // Listen for location mode changes
//        val locationFilter = IntentFilter(LocationManager.MODE_CHANGED_ACTION)
//        registerReceiver(locationModeReceiver, locationFilter)
//
//        // Listen for package changes (permission changes may trigger this)
//        val packageFilter = IntentFilter().apply {
//            addAction(Intent.ACTION_PACKAGE_CHANGED)
//            addAction(Intent.ACTION_PACKAGE_REMOVED)
//            addDataScheme("package")
//        }
//        registerReceiver(packageReceiver, packageFilter)
//
//        // Listen for app being resumed/foregrounded
//        val screenFilter = IntentFilter(Intent.ACTION_SCREEN_ON)
//        registerReceiver(screenReceiver, screenFilter)
//
//        // Listen for date/time changes
//        val timeFilter = IntentFilter().apply {
//            addAction(Intent.ACTION_TIME_CHANGED)
//            addAction(Intent.ACTION_DATE_CHANGED)
//            addAction(Intent.ACTION_TIMEZONE_CHANGED)
//        }
//        registerReceiver(dateTimeChangeReceiver, timeFilter)
//    }
//
//    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//        createNotificationChannel()
//
//        // ✅ CAPTURE SERVICE START TIME (reference for date/time change detection)
//        serviceStartTime = Date()
//
//        // Start foreground carefully (guard for background start restrictions)
//        try {
//            startForeground(NOTIFICATION_ID, buildNotification())
//        } catch (e: Exception) {
//            debugPrint("⚠️ [NATIVE] startForeground failed (background restriction): ${e.message}")
//            // If we cannot start foreground safely here, stop — OS will restart service when appropriate
//            stopSelf()
//            return START_NOT_STICKY
//        }
//
//        // Initialize previous states
//        wasLocationEnabled = isLocationEnabled()
//        wasPermissionGranted = checkLocationPermission()
//
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        // If service restarts and user was clocked in, validate current conditions immediately
//        if (clockedIn && !isFrozen) {
//            if (!wasPermissionGranted) {
//                debugPrint("🔐 [NATIVE] Service restarted — permission already REVOKED! Triggering clockout immediately.")
//                handler.postDelayed({ handleCriticalEvent("permission_revoked_auto") }, 500)
//                return START_STICKY
//            }
//            if (!wasLocationEnabled) {
//                debugPrint("📍 [NATIVE] Service restarted — location already OFF! Triggering clockout immediately.")
//                handler.postDelayed({ handleCriticalEvent("location_off_auto") }, 500)
//                return START_STICKY
//            }
//        }
//
//        startMonitoring()
//        return START_STICKY
//    }
//
//    private fun startMonitoring() {
//        checkRunnable = object : Runnable {
//            override fun run() {
//                checkLocationAndPermission()
//                handler.postDelayed(this, CHECK_INTERVAL)
//            }
//        }
//        handler.post(checkRunnable)
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
////            updateNotification("Timer frozen - Event logged", true)
//            handler.removeCallbacks(checkRunnable)
//            return
//        }
//
//        // CHECK FOR MIDNIGHT (11:58 PM) - WITH DUPLICATE GUARD
//        val now = Date()
//        val calendar = java.util.Calendar.getInstance()
//        calendar.time = now
//        val hour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
//        val minute = calendar.get(java.util.Calendar.MINUTE)
//
//        if (hour == 23 && minute == 58) {
//            val currentTime = System.currentTimeMillis()
//            // ✅ FIX: Only trigger once per minute
//            if (currentTime - lastEventTime > 60000) {
//                lastEventTime = currentTime
//                lastEventReason = "midnight_auto"
//                debugPrint("⏰ [POLLING] Midnight detected at 11:58 PM → handleCriticalEvent")
//                handleCriticalEvent("midnight_auto")
//                return
//            }
//        }
//
//        val currentLocationEnabled = isLocationEnabled()
//        val currentPermissionGranted = checkLocationPermission()
//
//        // Detect permission revoked (priority) - WITH DUPLICATE GUARD
//        if (wasPermissionGranted && !currentPermissionGranted) {
//            val currentTime = System.currentTimeMillis()
//            if (currentTime - lastEventTime > 5000 && lastEventReason != "permission_revoked_auto") {
//                lastEventTime = currentTime
//                lastEventReason = "permission_revoked_auto"
//                debugPrint("🔐 [POLLING] Permission REVOKED detected via polling → handleCriticalEvent")
//                handleCriticalEvent("permission_revoked_auto")
//                return
//            }
//        }
//
//        // Detect location turned off - WITH DUPLICATE GUARD
//        if (wasLocationEnabled && !currentLocationEnabled) {
//            val currentTime = System.currentTimeMillis()
//            if (currentTime - lastEventTime > 5000 && lastEventReason != "location_off_auto") {
//                lastEventTime = currentTime
//                lastEventReason = "location_off_auto"
//                debugPrint("📍 [POLLING] Location OFF detected → handleCriticalEvent")
//                handleCriticalEvent("location_off_auto")
//                return
//            }
//        }
//
//        // Update states
//        wasLocationEnabled = currentLocationEnabled
//        wasPermissionGranted = currentPermissionGranted
//
//        val status = if (currentLocationEnabled && currentPermissionGranted) {
//            "Monitoring - All OK"
//        } else {
//            "Issue detected - Processing..."
//        }
//        updateNotification(status, false)
//    }
//
//    private fun checkPermissionAndHandleRevocation() {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        if (!clockedIn || isFrozen) return
//
//        val currentPermissionGranted = checkLocationPermission()
//        if (!currentPermissionGranted) {
//            debugPrint("🔐 [NATIVE] Permission confirmed REVOKED → handleCriticalEvent")
//            handleCriticalEvent("permission_revoked_auto")
//        }
//    }
//
//    private fun debugPrint(message: String) {
//        android.util.Log.d("LocationMonitor", message)
//    }
//
//    // ✅ NEW: Modified handleCriticalEvent to accept custom event time
//    private fun handleCriticalEventWithTime(reason: String, eventTime: Date) {
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//
//        // Guard against duplicate handling
//        val alreadyFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//        if (alreadyFrozen) {
//            debugPrint("⚠️ [NATIVE] Already frozen, skipping duplicate event: $reason")
//            return
//        }
//
//        val editor = prefs.edit()
//
//        // ✅ FIX: Use provided eventTime instead of Date()
//        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(eventTime)
//        val elapsedAtEvent = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
//
//        editor.putBoolean(KEY_HAS_CRITICAL_EVENT, true)
//        editor.putBoolean(KEY_IS_TIMER_FROZEN, true)
//        editor.putString(KEY_EVENT_TIMESTAMP, timestamp)
//        editor.putString(KEY_EVENT_REASON, reason)
//        editor.putString(KEY_FROZEN_TIME, "00:00:00")
//        editor.putFloat(KEY_EVENT_DISTANCE, 0.0f)
//        editor.putFloat(KEY_EVENT_LAT, 0.0f)
//        editor.putFloat(KEY_EVENT_LNG, 0.0f)
//        editor.putBoolean(KEY_IS_CLOCKED_IN, false)
//
//        // ✅ CRITICAL: Mark GPX file for finalization on next app open
//        editor.putBoolean("flutter.pending_gpx_close", true)
//
//        // Save fastClockOut individual keys expected by Flutter
//        editor.putString("flutter.fastClockOutTime", timestamp)
//        editor.putFloat("flutter.fastClockOutDistance", 0.0f)
//        editor.putString("flutter.fastClockOutReason", reason)
//        editor.putBoolean("flutter.hasFastClockOutData", true)
//        editor.putBoolean("flutter.clockOutPending", true)
//
//        // JSON blob for fastClockOutData
//        val clockInTime = prefs.getString("flutter.clockInTime", "") ?: ""
//        val fastJson = """{"fast_attendanceId":"","fast_userId":"","fast_clockOutTime":"$timestamp","fast_totalTime":"00:00:00","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInTime"}"""
//        editor.putString("flutter.fastClockOutData", fastJson)
//
//        // Complete background payload for later sync
//        val bgPayload = buildBgPayload(timestamp, reason, elapsedAtEvent)
//        editor.putString(KEY_BG_CLOCKOUT_PAYLOAD, bgPayload)
//
//        // Commit synchronously to ensure data is persisted even if process is killed
//        try {
//            editor.commit()
//        } catch (e: Exception) {
//            // Fallback to apply if commit fails for any reason
//            editor.apply()
//        }
//
//        debugPrint("💾 [NATIVE] Critical event committed to disk: reason=$reason, timestamp=$timestamp (from event time: ${eventTime.time})")
//
//        showCriticalNotification(reason, timestamp)
//        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)
//
//        // Stop monitoring and cleanup
//        handler.removeCallbacks(checkRunnable)
//        unregisterAppOpsListener()
//
//        wakeUpBriefly()
//
//        try {
//            stopForeground(STOP_FOREGROUND_REMOVE)
//        } catch (e: Exception) {
//            // ignore
//        }
//        stopSelf()
//    }
//
//    // ✅ KEEP ORIGINAL: handleCriticalEvent for other events (uses Date())
//    private fun handleCriticalEvent(reason: String) {
//        handleCriticalEventWithTime(reason, Date())
//    }
//
//    private fun buildBgPayload(timestamp: String, reason: String, elapsedAtEvent: String): String {
//        return """{"timestamp":"$timestamp","reason":"$reason","elapsed_at_event":"$elapsedAtEvent","distance":0.0,"latitude":0.0,"longitude":0.0,"source":"native_background"}"""
//    }
//
//    private fun wakeUpBriefly() {
//        try {
//            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
//            val wakeLock = powerManager.newWakeLock(
//                PowerManager.PARTIAL_WAKE_LOCK,
//                "BookIT::CriticalEventWakeLock"
//            )
//            wakeLock.acquire(3000) // 3 seconds
//        } catch (e: Exception) {
//            e.printStackTrace()
//        }
//    }
//
//    private fun showCriticalNotification(reason: String, time: String) {
//        val title = when (reason) {
//            "location_off_auto" -> "⚠️ LOCATION TURNED OFF"
//            "permission_revoked_auto" -> "⚠️ PERMISSION REVOKED"
//            "midnight_auto" -> "⚠️ MIDNIGHT AUTO CLOCKOUT"
//            "time_changed_auto" -> "⚠️ DATE/TIME CHANGED"
//            else -> "⚠️ AUTO CLOCKOUT"
//        }
//
//        val message = "Time: $time\nApp was closed - Event captured. Open app to sync."
//
//        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//
//        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
//            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//        }
//        val pendingIntent = PendingIntent.getActivity(
//            this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//        )
//
//        val notification = NotificationCompat.Builder(this, URGENT_CHANNEL_ID)
//            .setContentTitle(title)
//            .setContentText(message)
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setPriority(NotificationCompat.PRIORITY_MAX)
//            .setCategory(NotificationCompat.CATEGORY_ALARM)
//            .setAutoCancel(true)
//            .setContentIntent(pendingIntent)
//            .setVibrate(longArrayOf(0, 1000, 500, 1000))
//            .setLights(android.graphics.Color.RED, 1000, 500)
//            .build()
//
//        notificationManager.notify(9999, notification)
//    }
//
//    private fun isLocationEnabled(): Boolean {
//        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
//            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
//            locationManager.isLocationEnabled
//        } else {
//            val mode = Settings.Secure.getInt(
//                contentResolver,
//                Settings.Secure.LOCATION_MODE,
//                Settings.Secure.LOCATION_MODE_OFF
//            )
//            mode != Settings.Secure.LOCATION_MODE_OFF
//        }
//    }
//
//    private fun checkLocationPermission(): Boolean {
//        return try {
//            ContextCompat.checkSelfPermission(
//                this,
//                Manifest.permission.ACCESS_FINE_LOCATION
//            ) == PackageManager.PERMISSION_GRANTED ||
//                    ContextCompat.checkSelfPermission(
//                        this,
//                        Manifest.permission.ACCESS_COARSE_LOCATION
//                    ) == PackageManager.PERMISSION_GRANTED
//        } catch (e: Exception) {
//            debugPrint("⚠️ [NATIVE] Permission check error: ${e.message}")
//            false
//        }
//    }
//
//    private val locationModeReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            if (intent?.action == LocationManager.MODE_CHANGED_ACTION) {
//                debugPrint("📡 [BROADCAST] Location mode changed")
//                handler.post { checkLocationAndPermission() }
//            }
//        }
//    }
//
//    private val packageReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            val changedPkg = intent?.data?.schemeSpecificPart
//            // React only when it's our package or package event is general
//            if (changedPkg == null || changedPkg == packageName) {
//                debugPrint("📡 [BROADCAST] Package/permission event for our app → checking permission")
//                handler.post { checkPermissionAndHandleRevocation() }
//            } else {
//                // General package event — re-check as fallback
//                handler.post { checkLocationAndPermission() }
//            }
//        }
//    }
//
//    private val screenReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            debugPrint("📡 [BROADCAST] Screen ON → checking state")
//            handler.post { checkLocationAndPermission() }
//        }
//    }
//
//    // ✅ FIXED: Date/Time change receiver with duplicate guard and serviceStartTime
//    private val dateTimeChangeReceiver = object : BroadcastReceiver() {
//        override fun onReceive(context: Context?, intent: Intent?) {
//            val action = intent?.action ?: return
//            if (action == Intent.ACTION_TIME_CHANGED ||
//                action == Intent.ACTION_DATE_CHANGED ||
//                action == Intent.ACTION_TIMEZONE_CHANGED) {
//
//                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//                val isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//                val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//                if (isClockedIn && !isFrozen) {
//                    // ✅ FIX: DUPLICATE GUARD - Only trigger if enough time has passed since last event
//                    val currentTime = System.currentTimeMillis()
//                    if (currentTime - lastEventTime > 5000 && lastEventReason != "time_changed_auto") {
//                        lastEventTime = currentTime
//                        lastEventReason = "time_changed_auto"
//                        debugPrint("⏰ [NATIVE] Date/Time changed by user! Action: $action → Triggering clockout with serviceStartTime")
//                        // ✅ FIX: USE SERVICE START TIME (when user was clocked in), NOT current time
//                        handler.post { handleCriticalEventWithTime("time_changed_auto", serviceStartTime) }
//                    } else {
//                        debugPrint("⏰ [NATIVE] Date/Time broadcast duplicate — ignoring (last event: ${currentTime - lastEventTime}ms ago, reason: $lastEventReason)")
//                    }
//                } else {
//                    debugPrint("⏰ [NATIVE] Date/Time changed but user not clocked in (isClockedIn=$isClockedIn, isFrozen=$isFrozen) — ignoring")
//                }
//            }
//        }
//    }
//
//    private fun createNotificationChannel() {
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//            val serviceChannel = NotificationChannel(
//                CHANNEL_ID,
//                "Location Monitor Service",
//                NotificationManager.IMPORTANCE_LOW
//            ).apply {
//                description = "Monitors location status for attendance tracking"
//            }
//
//            val urgentChannel = NotificationChannel(
//                URGENT_CHANNEL_ID,
//                "URGENT Auto Clockout",
//                NotificationManager.IMPORTANCE_HIGH
//            ).apply {
//                description = "Critical auto clockout notifications"
//                enableVibration(true)
//                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
//                enableLights(true)
//                lightColor = android.graphics.Color.RED
//            }
//
//            val manager = getSystemService(NotificationManager::class.java)
//            manager.createNotificationChannel(serviceChannel)
//            manager.createNotificationChannel(urgentChannel)
//        }
//    }
//
//    private fun buildNotification(): Notification {
//        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
//        val pendingIntent = PendingIntent.getActivity(
//            this,
//            0,
//            launchIntent,
//            PendingIntent.FLAG_IMMUTABLE
//        )
//
//        return NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle("BookIT Attendance Active")
//            .setContentText("Monitoring location status...")
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setContentIntent(pendingIntent)
//            .setOngoing(true)
//            .setSilent(true)
//            .build()
//    }
//
//    private fun updateNotification(text: String, isAlert: Boolean) {
//        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
//        val pendingIntent = PendingIntent.getActivity(
//            this,
//            0,
//            launchIntent,
//            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//        )
//
//        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
//            .setContentTitle(if (isAlert) "⚠️ ATTENTION REQUIRED" else "BookIT Attendance Active")
//            .setContentText(text)
//            .setSmallIcon(R.mipmap.ic_launcher)
//            .setContentIntent(pendingIntent)
//            .setOngoing(true)
//            .setSilent(!isAlert)
//            .apply {
//                if (isAlert) {
//                    setColor(android.graphics.Color.RED)
//                    setLights(android.graphics.Color.RED, 1000, 500)
//                }
//            }
//            .build()
//
//        val notificationManager = getSystemService(NotificationManager::class.java)
//        notificationManager.notify(NOTIFICATION_ID, notification)
//    }
//
//    override fun onBind(intent: Intent?): IBinder? = null
//
//    // Ensure service restarts when app removed from recents
//    override fun onTaskRemoved(rootIntent: Intent?) {
//        super.onTaskRemoved(rootIntent)
//        debugPrint("🔄 [NATIVE] App removed from recents — ensuring service restarts")
//
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        if (isClockedIn && !isFrozen) {
//            val restartIntent = Intent(applicationContext, LocationMonitorService::class.java)
//            val restartPendingIntent = PendingIntent.getService(
//                applicationContext, 1, restartIntent,
//                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
//            )
//            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
//            alarmManager.set(
//                AlarmManager.ELAPSED_REALTIME,
//                android.os.SystemClock.elapsedRealtime() + 1000,
//                restartPendingIntent
//            )
//            debugPrint("⏱️ [NATIVE] Service restart scheduled in 1 second")
//        }
//    }
//
//    override fun onDestroy() {
//        // Last-chance save: if the service is destroyed while user is clocked in, ensure data persisted
//        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
//        val isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
//        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)
//
//        if (isClockedIn && !isFrozen) {
//            val permissionRevoked = !checkLocationPermission()
//            val locationOff = !isLocationEnabled()
//
//            if (permissionRevoked || locationOff) {
//                val reason = if (permissionRevoked) "permission_revoked_auto" else "location_off_auto"
//                debugPrint("🔴 [NATIVE onDestroy] Saving clockout! reason=$reason, permRevoked=$permissionRevoked, locOff=$locationOff")
//
//                val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())
//                val elapsedAtEvent = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"
//                val clockInTime = prefs.getString("flutter.clockInTime", "") ?: ""
//
//                val editor = prefs.edit()
//                editor.putBoolean(KEY_HAS_CRITICAL_EVENT, true)
//                editor.putBoolean(KEY_IS_TIMER_FROZEN, true)
//                editor.putString(KEY_EVENT_TIMESTAMP, timestamp)
//                editor.putString(KEY_EVENT_REASON, reason)
//                editor.putString(KEY_FROZEN_TIME, "00:00:00")
//                editor.putFloat(KEY_EVENT_DISTANCE, 0.0f)
//                editor.putFloat(KEY_EVENT_LAT, 0.0f)
//                editor.putFloat(KEY_EVENT_LNG, 0.0f)
//                editor.putBoolean(KEY_IS_CLOCKED_IN, false)
//
//                // ✅ CRITICAL: Mark GPX file for finalization on next app open
//                editor.putBoolean("flutter.pending_gpx_close", true)
//
//                editor.putString("flutter.fastClockOutTime", timestamp)
//                editor.putFloat("flutter.fastClockOutDistance", 0.0f)
//                editor.putString("flutter.fastClockOutReason", reason)
//                editor.putBoolean("flutter.hasFastClockOutData", true)
//                editor.putBoolean("flutter.clockOutPending", true)
//
//                val fastJson = """{"fast_attendanceId":"","fast_userId":"","fast_clockOutTime":"$timestamp","fast_totalTime":"00:00:00","fast_totalDistance":0.0,"fast_latOut":0.0,"fast_lngOut":0.0,"fast_address":"","fast_reason":"$reason","fast_savedAt":"${System.currentTimeMillis()}","fast_clockInTime":"$clockInTime"}"""
//                editor.putString("flutter.fastClockOutData", fastJson)
//
//                val bgPayload = """{"timestamp":"$timestamp","reason":"$reason","elapsed_at_event":"$elapsedAtEvent","distance":0.0,"latitude":0.0,"longitude":0.0,"source":"on_destroy"}"""
//                editor.putString(KEY_BG_CLOCKOUT_PAYLOAD, bgPayload)
//
//                try {
//                    editor.commit()
//                } catch (e: Exception) {
//                    editor.apply()
//                }
//
//                // Show notification to prompt user to open app for sync
//                try {
//                    createNotificationChannel()
//                    val title = if (permissionRevoked) "⚠️ PERMISSION REVOKED" else "⚠️ LOCATION TURNED OFF"
//                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
//                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
//                    }
//                    val pendingIntent = PendingIntent.getActivity(
//                        this, 0, launchIntent,
//                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
//                    )
//                    val notification = NotificationCompat.Builder(this, URGENT_CHANNEL_ID)
//                        .setContentTitle(title)
//                        .setContentText("Auto clockout saved. Open app to sync.")
//                        .setSmallIcon(R.mipmap.ic_launcher)
//                        .setPriority(NotificationCompat.PRIORITY_MAX)
//                        .setCategory(NotificationCompat.CATEGORY_ALARM)
//                        .setAutoCancel(true)
//                        .setContentIntent(pendingIntent)
//                        .setVibrate(longArrayOf(0, 1000, 500, 1000))
//                        .build()
//                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//                    notificationManager.notify(9998, notification)
//                    debugPrint("✅ [NATIVE onDestroy] Notification shown, data saved with timestamp: $timestamp")
//                } catch (e: Exception) {
//                    debugPrint("⚠️ [NATIVE onDestroy] Notification error: ${e.message}")
//                }
//            } else {
//                debugPrint("🟡 [NATIVE onDestroy] Clocked in but permission/location OK — normal shutdown")
//            }
//        }
//
//        super.onDestroy()
//        handler.removeCallbacks(checkRunnable)
//        unregisterAppOpsListener()
//        try {
//            unregisterReceiver(locationModeReceiver)
//            unregisterReceiver(packageReceiver)
//            unregisterReceiver(screenReceiver)
//            unregisterReceiver(dateTimeChangeReceiver)
//        } catch (e: Exception) {
//            // Receiver might not be registered
//        }
//    }
//}

// ============================================================
//  LocationMonitorService.kt — MERGED: Location Monitoring + MQTT
//  Monitors: Location OFF, Permission revoked, Midnight, Date/Time change
//  Publishes: GPS data via MQTT when connected, queues when offline
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

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LocationMonitorService : Service() {
    private val CHANNEL_ID = "location_monitor_channel"
    private val URGENT_CHANNEL_ID = "urgent_auto_clockout_channel"
    private val NOTIFICATION_ID = 1001
    private val CHECK_INTERVAL = 2000L
    private val GPS_PUBLISH_MS = 5000L

    // MQTT
    private val MQTT_HOST = "103.149.33.102"
    private val MQTT_PORT = 1883
    private val MQTT_TOPIC = "gps/location"

    // SharedPreferences keys
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val KEY_IS_CLOCKED_IN = "flutter.isClockedIn"
    private val KEY_HAS_CRITICAL_EVENT = "flutter.has_critical_event_pending"
    private val KEY_EVENT_TIMESTAMP = "flutter.critical_event_timestamp"
    private val KEY_EVENT_REASON = "flutter.critical_event_reason"
    private val KEY_IS_TIMER_FROZEN = "flutter.is_timer_frozen"
    private val KEY_ELAPSED_TIME = "flutter.elapsed_time"

    private lateinit var handler: Handler
    private lateinit var checkRunnable: Runnable
    private lateinit var gpsRunnable: Runnable

    private var wasLocationEnabled = true
    private var wasPermissionGranted = true
    private var isClockedIn = false
    private var lastEventTime: Long = 0
    private var lastEventReason: String = ""
    private var serviceStartTime: Date = Date()

    // Location
    private var lastLat = 0.0
    private var lastLon = 0.0
    private var lastAccuracy = 0f
    private var lastSpeed = 0f
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null

    // MQTT
    private var mqttClient: MqttAsyncClient? = null
    private var isMqttConnected = false
    private var isConnecting = false
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // AppOps
    private var appOpsManager: AppOpsManager? = null
    private var appOpsCallback: AppOpsManager.OnOpChangedListener? = null

    companion object {
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

        wasLocationEnabled = isLocationEnabled()
        wasPermissionGranted = checkLocationPermission()

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val clockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

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
        val now = Date()
        val calendar = java.util.Calendar.getInstance()
        calendar.time = now
        val hour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
        val minute = calendar.get(java.util.Calendar.MINUTE)

        if (hour == 23 && minute == 58) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 60000) {
                lastEventTime = currentTime
                lastEventReason = "midnight_auto"
                debugPrint("⏰ Midnight detected → handleCriticalEvent")
                handleCriticalEvent("midnight_auto")
                return
            }
        }

        val currentLocationEnabled = isLocationEnabled()
        val currentPermissionGranted = checkLocationPermission()

        if (wasPermissionGranted && !currentPermissionGranted) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 5000 && lastEventReason != "permission_revoked_auto") {
                lastEventTime = currentTime
                lastEventReason = "permission_revoked_auto"
                debugPrint("🔐 Permission REVOKED → handleCriticalEvent")
                handleCriticalEvent("permission_revoked_auto")
                return
            }
        }

        if (wasLocationEnabled && !currentLocationEnabled) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastEventTime > 5000 && lastEventReason != "location_off_auto") {
                lastEventTime = currentTime
                lastEventReason = "location_off_auto"
                debugPrint("📍 Location OFF → handleCriticalEvent")
                handleCriticalEvent("location_off_auto")
                return
            }
        }

        wasLocationEnabled = currentLocationEnabled
        wasPermissionGranted = currentPermissionGranted

        val status = if (currentLocationEnabled && currentPermissionGranted) {
            "Monitoring - All OK | MQTT: ${if (isMqttConnected) "●" else "○"}"
        } else {
            "Issue detected - Processing..."
        }
        updateNotification(status, false)
    }

    private fun handleCriticalEvent(reason: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alreadyFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (alreadyFrozen) {
            debugPrint("⚠️ Already frozen, skipping duplicate event: $reason")
            return
        }

        val editor = prefs.edit()
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(serviceStartTime)
        val elapsedAtEvent = prefs.getString(KEY_ELAPSED_TIME, "00:00:00") ?: "00:00:00"

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

        try {
            editor.commit()
        } catch (e: Exception) {
            editor.apply()
        }

        debugPrint("💾 Critical event committed: $reason at $timestamp")
        showCriticalNotification(reason, timestamp)
        updateNotification("⚠️ AUTO CLOCKOUT: $reason", true)

        handler.removeCallbacks(checkRunnable)
        handler.removeCallbacks(gpsRunnable)
        disconnectMqtt()

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            // ignore
        }
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
                    lastLat = loc.latitude
                    lastLon = loc.longitude
                    lastAccuracy = loc.accuracy
                    lastSpeed = loc.speed
                }

                @Deprecated("Deprecated")
                override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
                override fun onProviderEnabled(p: String) {}
                override fun onProviderDisabled(p: String) {}
            }

            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).forEach { p ->
                try {
                    if (locationManager?.isProviderEnabled(p) == true) {
                        locationManager?.requestLocationUpdates(p, 4000L, 0f, locationListener!!, Looper.getMainLooper())
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
        try {
            locationListener?.let { locationManager?.removeUpdates(it) }
        } catch (_: Exception) {}
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
            debugPrint("Connecting to tcp://$MQTT_HOST:$MQTT_PORT id=$clientId")

            safeCloseClient()

            mqttClient = MqttAsyncClient(
                "tcp://$MQTT_HOST:$MQTT_PORT", clientId, MemoryPersistence()
            )

            mqttClient?.setCallback(object : MqttCallback {
                override fun connectionLost(cause: Throwable?) {
                    isMqttConnected = false
                    isConnecting = false
                    debugPrint("Connection lost: ${cause?.message}")
                    handler.postDelayed({ connectMqtt() }, 3000L)
                }

                override fun messageArrived(topic: String?, message: MqttMessage?) {}
                override fun deliveryComplete(token: IMqttDeliveryToken?) {}
            })

            val opts = MqttConnectOptions().apply {
                isCleanSession = true
                keepAliveInterval = 30
                connectionTimeout = 10
                isAutomaticReconnect = false
            }

            mqttClient?.connect(opts, null, object : IMqttActionListener {
                override fun onSuccess(asyncActionToken: IMqttToken?) {
                    isMqttConnected = true
                    isConnecting = false
                    debugPrint("MQTT Connected!")
                    updateNotification("Online | GPS publishing", false)
                }

                override fun onFailure(asyncActionToken: IMqttToken?, exception: Throwable?) {
                    isMqttConnected = false
                    isConnecting = false
                    debugPrint("Connect failed: ${exception?.message}")
                }
            })
        } catch (e: Exception) {
            isMqttConnected = false
            isConnecting = false
            debugPrint("Exception in connectMqtt: ${e.message}")
        }
    }

    private fun publishLocationViaMqtt() {
        if (!isMqttConnected || (lastLat == 0.0 && lastLon == 0.0)) return
        try {
            val payload = buildPayload()
            val msg = MqttMessage(payload.toByteArray(Charsets.UTF_8))
            msg.qos = 1
            mqttClient?.publish(MQTT_TOPIC, msg)
            debugPrint("Published ✓ lat=$lastLat lon=$lastLon")
        } catch (e: Exception) {
            debugPrint("Publish error: ${e.message}")
            isMqttConnected = false
        }
    }

    private fun buildPayload(): String {
        val ts = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).format(Date())
        val deviceId = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString("user_name", "DEVICE_000") ?: "DEVICE_000"

        return JSONObject().apply {
            put("device_id", deviceId)
            put("track_id", System.currentTimeMillis())
            put("lat", lastLat)
            put("lon", lastLon)
            put("accuracy", lastAccuracy.toDouble())
            put("speed", lastSpeed.toDouble())
            put("timestamp", ts)
            put("source", "background_service")
        }.toString()
    }

    private fun disconnectMqtt() {
        try {
            if (mqttClient?.isConnected == true) {
                mqttClient?.disconnect()
            }
        } catch (_: Exception) {}
        isMqttConnected = false
        safeCloseClient()
    }

    private fun safeCloseClient() {
        try {
            mqttClient?.close()
        } catch (_: Exception) {}
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
        try {
            networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) }
        } catch (_: Exception) {}
        networkCallback = null
    }

    // ================================================================== //
    //  AppOps Listener (Permission revocation detection)
    // ================================================================== //

    private fun registerAppOpsListener() {
        try {
            appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val listener = AppOpsManager.OnOpChangedListener { op, pkg ->
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
        val locationFilter = IntentFilter(LocationManager.MODE_CHANGED_ACTION)
        registerReceiver(locationModeReceiver, locationFilter)

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
            if (action in listOf(Intent.ACTION_TIME_CHANGED, Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
                val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

                if (isClockedIn && !isFrozen) {
                    val currentTime = System.currentTimeMillis()
                    if (currentTime - lastEventTime > 5000 && lastEventReason != "time_changed_auto") {
                        lastEventTime = currentTime
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
                CHANNEL_ID,
                "Location Monitor Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors location + MQTT GPS publishing"
            }

            val urgentChannel = NotificationChannel(
                URGENT_CHANNEL_ID,
                "URGENT Auto Clockout",
                NotificationManager.IMPORTANCE_HIGH
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
            .setContentTitle("BookIT Attendance Active")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun updateNotification(text: String, isAlert: Boolean) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(if (isAlert) "⚠️ ATTENTION REQUIRED" else "BookIT Attendance Active")
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

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun showCriticalNotification(reason: String, time: String) {
        val title = when (reason) {
            "location_off_auto" -> "⚠️ LOCATION TURNED OFF"
            "permission_revoked_auto" -> "⚠️ PERMISSION REVOKED"
            "midnight_auto" -> "⚠️ MIDNIGHT AUTO CLOCKOUT"
            else -> "⚠️ AUTO CLOCKOUT"
        }

        val message = "Time: $time\nApp was closed - Event captured. Open app to sync."

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
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

        notificationManager.notify(9999, notification)
    }

    // ================================================================== //
    //  Helper Methods
    // ================================================================== //

    private fun isLocationEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            locationManager.isLocationEnabled
        } else {
            try {
                val mode = Settings.Secure.getInt(
                    contentResolver,
                    Settings.Secure.LOCATION_MODE,
                    Settings.Secure.LOCATION_MODE_OFF
                )
                mode != Settings.Secure.LOCATION_MODE_OFF
            } catch (e: Exception) {
                false
            }
        }
    }

    private fun checkLocationPermission(): Boolean {
        return try {
            (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED) ||
                    (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED)
        } catch (e: Exception) {
            false
        }
    }

    private fun debugPrint(message: String) {
        android.util.Log.d("LocationMonitor", message)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        debugPrint("App removed from recents — ensuring service restarts")

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isClockedIn = prefs.getBoolean(KEY_IS_CLOCKED_IN, false)
        val isFrozen = prefs.getBoolean(KEY_IS_TIMER_FROZEN, false)

        if (isClockedIn && !isFrozen) {
            val restartIntent = Intent(applicationContext, LocationMonitorService::class.java)
            val restartPendingIntent = PendingIntent.getService(
                applicationContext, 1, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME,
                android.os.SystemClock.elapsedRealtime() + 1000,
                restartPendingIntent
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