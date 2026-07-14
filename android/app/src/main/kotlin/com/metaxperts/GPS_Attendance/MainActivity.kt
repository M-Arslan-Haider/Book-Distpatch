////package com.metaxperts.bookdispatch
////
////import android.Manifest
////import android.content.Context
////import android.content.Intent
////import android.content.pm.PackageManager
////import android.net.Uri
////import android.os.Build
////import android.os.Bundle
////import android.os.PowerManager
////import android.provider.Settings
////import android.telephony.SubscriptionManager
////import androidx.core.content.ContextCompat
////import com.google.android.gms.common.GoogleApiAvailability
////import com.google.android.gms.security.ProviderInstaller
////import com.google.android.play.core.integrity.IntegrityManagerFactory
////import com.google.android.play.core.integrity.IntegrityTokenRequest
////import io.flutter.embedding.android.FlutterFragmentActivity
////import io.flutter.embedding.engine.FlutterEngine
////import io.flutter.plugin.common.MethodChannel
////
////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
////
////    private val LOCATION_CHANNEL        = "com.metaxperts.bookdispatch/location_monitor"
////    private val MQTT_CHANNEL            = "com.example.untitled2/mqtt_service"
////    private val SIM_CHANNEL             = "sim_info_channel"
////    private val AUTO_TIME_CHANNEL       = "com.metaxperts.bookdispatch/auto_time_check"
////    private val PLAY_INTEGRITY_CHANNEL  = "play_integrity"
////    private val GPS_FRAUD_CHANNEL = "com.metaxperts.bookdispatch/gps_fraud"
////
////    override fun onCreate(savedInstanceState: Bundle?) {
////        super.onCreate(savedInstanceState)
////        installProvider()
////        GeofenceViolationNotificationService.startService(this)
////        TaskNotificationService.createChannel(this)
////    }
////
////    private fun installProvider() {
////        ProviderInstaller.installIfNeededAsync(this, this)
////    }
////
////    override fun onProviderInstalled() {}
////
////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
////    }
////
////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
////        super.configureFlutterEngine(flutterEngine)
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ PLAY INTEGRITY CHANNEL — NEW
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAY_INTEGRITY_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                if (call.method == "getIntegrityToken") {
////                    val cloudProjectNumber = call.argument<String>("cloudProjectNumber")?.toLongOrNull()
////                        ?: run {
////                            result.error("INVALID_ARG", "cloudProjectNumber is required", null)
////                            return@setMethodCallHandler
////                        }
////                    val nonce = call.argument<String>("nonce") ?: java.util.UUID.randomUUID().toString()
////                    val integrityManager = IntegrityManagerFactory.create(applicationContext)
////                    val request = IntegrityTokenRequest.builder()
////                        .setCloudProjectNumber(cloudProjectNumber)
////                        .setNonce(nonce)
////                        .build()
////                    integrityManager.requestIntegrityToken(request)
////                        .addOnSuccessListener { response -> result.success(response.token()) }
////                        .addOnFailureListener { e -> result.error("INTEGRITY_ERROR", e.message, null) }
////                } else {
////                    result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ AUTO TIME CHECK CHANNEL
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_TIME_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                when (call.method) {
////
////                    "isAutoTimeEnabled" -> {
////                        try {
////                            val autoTime = Settings.Global.getInt(
////                                contentResolver,
////                                Settings.Global.AUTO_TIME,
////                                0
////                            )
////                            val isEnabled = autoTime == 1
////                            android.util.Log.d(
////                                "MainActivity",
////                                "⏰ [AUTO_TIME] Settings.Global.AUTO_TIME = $autoTime → isEnabled=$isEnabled"
////                            )
////                            result.success(isEnabled)
////                        } catch (e: Exception) {
////                            android.util.Log.e("MainActivity", "❌ [AUTO_TIME] Error: ${e.message}")
////                            result.error("AUTO_TIME_ERROR", e.message, null)
////                        }
////                    }
////
////                    "openDateTimeSettings" -> {
////                        try {
////                            val intent = Intent(Settings.ACTION_DATE_SETTINGS)
////                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
////                            startActivity(intent)
////                            result.success(null)
////                        } catch (e: Exception) {
////                            android.util.Log.e(
////                                "MainActivity",
////                                "❌ [AUTO_TIME] Cannot open Date settings: ${e.message}"
////                            )
////                            try {
////                                val fallback = Intent(Settings.ACTION_SETTINGS)
////                                fallback.flags = Intent.FLAG_ACTIVITY_NEW_TASK
////                                startActivity(fallback)
////                            } catch (_: Exception) {}
////                            result.success(null)
////                        }
////                    }
////
////                    else -> result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ LOCATION MONITOR CHANNEL
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                when (call.method) {
////
////                    "startMonitoring" -> {
////                        try {
////                            val intent = Intent(this, LocationMonitorService::class.java)
////                            startForegroundService(intent)
////                            result.success(true)
////                        } catch (e: Exception) {
////                            result.error("START_ERROR", e.message, null)
////                        }
////                    }
////
////                    "stopMonitoring" -> {
////                        try {
////                            val intent = Intent(this, LocationMonitorService::class.java)
////                            stopService(intent)
////                            result.success(true)
////                        } catch (e: Exception) {
////                            result.error("STOP_ERROR", e.message, null)
////                        }
////                    }
////
////                    "isServiceRunning" -> {
////                        val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
////                        val running = manager.getRunningServices(Integer.MAX_VALUE)
////                            .any { it.service.className == LocationMonitorService::class.java.name }
////                        result.success(running)
////                    }
////
////                    "startOvertimeMonitor" -> {
////                        android.util.Log.d("MainActivity", "▶️ [OT] startOvertimeMonitor called from Flutter")
////                        OvertimeMonitorService.start(this)
////                        result.success(true)
////                    }
////
////                    "stopOvertimeMonitor" -> {
////                        android.util.Log.d("MainActivity", "⏹️ [OT] stopOvertimeMonitor called from Flutter")
////                        OvertimeMonitorService.stop(this)
////                        result.success(true)
////                    }
////
////                    "scheduleIntervalSelfieAlarms" -> {
////                        IntervalSelfieAlarmReceiver.scheduleAll(applicationContext)
////                        result.success(true)
////                    }
////
////                    "cancelIntervalSelfieAlarms" -> {
////                        IntervalSelfieAlarmReceiver.cancelAll(applicationContext)
////                        result.success(true)
////                    }
////
////                    "isDeveloperOptionsEnabled" -> {
////                        try {
////                            val devOptions = Settings.Global.getInt(
////                                contentResolver,
////                                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
////                                0
////                            )
////                            val isEnabled = devOptions != 0
////                            android.util.Log.d(
////                                "MainActivity",
////                                "🛠️ [DEV_OPTIONS] DEVELOPMENT_SETTINGS_ENABLED = $devOptions → isEnabled=$isEnabled"
////                            )
////                            result.success(isEnabled)
////                        } catch (e: Exception) {
////                            android.util.Log.e("MainActivity", "❌ [DEV_OPTIONS] Error: ${e.message}")
////                            result.error("DEV_OPTIONS_ERROR", e.message, null)
////                        }
////                    }
////
////                    "openDeveloperSettings" -> {
////                        try {
////                            val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
////                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
////                            startActivity(intent)
////                            result.success(null)
////                        } catch (e: Exception) {
////                            android.util.Log.e(
////                                "MainActivity",
////                                "❌ [DEV_OPTIONS] Cannot open Developer settings: ${e.message}"
////                            )
////                            try {
////                                val fallback = Intent(Settings.ACTION_SETTINGS)
////                                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
////                                startActivity(fallback)
////                            } catch (_: Exception) {}
////                            result.success(null)
////                        }
////                    }
////
////                    else -> result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ MQTT SERVICE CHANNEL (unchanged)
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MQTT_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                when (call.method) {
////                    "startService" -> {
////                        if (hasLocationPermission()) {
////                            val deviceId    = call.argument<String>("deviceId")    ?: ""
////                            val companyCode = call.argument<String>("companyCode") ?: ""
////                            val empName     = call.argument<String>("empName")     ?: ""
////
////                            android.util.Log.d("MainActivity",
////                                "startService → deviceId=$deviceId company=$companyCode emp=$empName")
////
////                            if (deviceId.isNotEmpty() && companyCode.isNotEmpty()) {
////                                LocationMonitorService.start(this, deviceId, companyCode, empName)
////                            } else {
////                                LocationMonitorService.start(this)
////                            }
////                            result.success(null)
////                        } else {
////                            result.error("NO_PERMISSION", "Location permission not granted", null)
////                        }
////                    }
////                    "stopService" -> {
////                        LocationMonitorService.stop(this)
////                        result.success(null)
////                    }
////                    "requestBatteryOptimization" -> {
////                        try {
////                            val pm = getSystemService(POWER_SERVICE) as PowerManager
////                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
////                                intent.data = Uri.parse("package:$packageName")
////                                startActivity(intent)
////                            }
////                            result.success(null)
////                        } catch (e: Exception) {
////                            result.success(null)
////                        }
////                    }
////                    else -> result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ REAL LOCATION CHANNEL (unchanged)
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.metaxperts/real_location")
////            .setMethodCallHandler { call, result ->
////                if (call.method == "getRealLocation") {
////                    try {
////                        val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
////                        val location = lm.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
////                        if (location != null) {
////                            result.success(mapOf(
////                                "latitude"  to location.latitude,
////                                "longitude" to location.longitude
////                            ))
////                        } else {
////                            result.error("UNAVAILABLE", "Real GPS not available", null)
////                        }
////                    } catch (e: Exception) {
////                        result.error("ERROR", e.message, null)
////                    }
////                } else {
////                    result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ SIM INFO CHANNEL (unchanged)
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                if (call.method == "getSimInfo") {
////                    try {
////                        val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
////                        val subs = subManager.activeSubscriptionInfoList
////                        if (!subs.isNullOrEmpty()) {
////                            val simInfo = subs.mapIndexed { i, info ->
////                                "SIM${i + 1}: ${info.carrierName ?: "Unknown"}"
////                            }.joinToString(", ")
////                            result.success(simInfo)
////                        } else {
////                            result.success("No SIM")
////                        }
////                    } catch (e: Exception) {
////                        result.success("unavailable")
////                    }
////                } else {
////                    result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ TASK NOTIFICATION CHANNEL (unchanged)
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "task_notifications")
////            .setMethodCallHandler { call, result ->
////                if (call.method == "showTaskNotification") {
////                    TaskNotificationService.showNewTaskNotification(
////                        context    = this,
////                        taskTitle  = call.argument<String>("taskTitle")  ?: "",
////                        taskDesc   = call.argument<String>("taskDesc")   ?: "",
////                        assignedBy = call.argument<String>("assignedBy") ?: ""
////                    )
////                    result.success(null)
////                } else {
////                    result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ GPS FRAUD DETECTION CHANNEL
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GPS_FRAUD_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                when (call.method) {
////                    "getSatelliteCount" -> {
////                        val count = LocationMonitorService.lastSatelliteCount
////                        android.util.Log.d("MainActivity",
////                            "🛰️ [GPS FRAUD] getSatelliteCount → $count")
////                        result.success(count)
////                    }
////                    else -> result.notImplemented()
////                }
////            }
////    }
////
////
////    private fun hasLocationPermission(): Boolean {
////        return ContextCompat.checkSelfPermission(
////            this, Manifest.permission.ACCESS_FINE_LOCATION
////        ) == PackageManager.PERMISSION_GRANTED ||
////                ContextCompat.checkSelfPermission(
////                    this, Manifest.permission.ACCESS_COARSE_LOCATION
////                ) == PackageManager.PERMISSION_GRANTED
////    }
////}
//
////package com.metaxperts.bookdispatch
////
////import android.Manifest
////import android.content.Context
////import android.content.Intent
////import android.content.pm.PackageManager
////import android.net.Uri
////import android.os.Build
////import android.os.Bundle
////import android.os.PowerManager
////import android.provider.Settings
////import android.telephony.SubscriptionManager
////import androidx.core.content.ContextCompat
////import com.google.android.gms.common.GoogleApiAvailability
////import com.google.android.gms.security.ProviderInstaller
////import com.google.android.play.core.integrity.IntegrityManagerFactory
////import com.google.android.play.core.integrity.IntegrityTokenRequest
////import io.flutter.embedding.android.FlutterFragmentActivity
////import io.flutter.embedding.engine.FlutterEngine
////import io.flutter.plugin.common.MethodChannel
////
////class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
////
////    private val LOCATION_CHANNEL        = "com.metaxperts.bookdispatch/location_monitor"
////    private val MQTT_CHANNEL            = "com.example.untitled2/mqtt_service"
////    private val SIM_CHANNEL             = "sim_info_channel"
////    private val AUTO_TIME_CHANNEL       = "com.metaxperts.bookdispatch/auto_time_check"
////    private val PLAY_INTEGRITY_CHANNEL  = "play_integrity"
////    private val GPS_FRAUD_CHANNEL = "com.metaxperts.bookdispatch/gps_fraud"
////
////    override fun onCreate(savedInstanceState: Bundle?) {
////        super.onCreate(savedInstanceState)
////        installProvider()
////        GeofenceViolationNotificationService.startService(this)
////        TaskNotificationService.createChannel(this)
////    }
////
////    private fun installProvider() {
////        ProviderInstaller.installIfNeededAsync(this, this)
////    }
////
////    override fun onProviderInstalled() {}
////
////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
////    }
////
////    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
////        super.configureFlutterEngine(flutterEngine)
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ PLAY INTEGRITY CHANNEL — NEW
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAY_INTEGRITY_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                if (call.method == "getIntegrityToken") {
////                    val cloudProjectNumber = call.argument<String>("cloudProjectNumber")?.toLongOrNull()
////                        ?: run {
////                            result.error("INVALID_ARG", "cloudProjectNumber is required", null)
////                            return@setMethodCallHandler
////                        }
////                    val nonce = call.argument<String>("nonce") ?: java.util.UUID.randomUUID().toString()
////                    val integrityManager = IntegrityManagerFactory.create(applicationContext)
////                    val request = IntegrityTokenRequest.builder()
////                        .setCloudProjectNumber(cloudProjectNumber)
////                        .setNonce(nonce)
////                        .build()
////                    integrityManager.requestIntegrityToken(request)
////                        .addOnSuccessListener { response -> result.success(response.token()) }
////                        .addOnFailureListener { e -> result.error("INTEGRITY_ERROR", e.message, null) }
////                } else {
////                    result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ AUTO TIME CHECK CHANNEL
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_TIME_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                when (call.method) {
////
////                    "isAutoTimeEnabled" -> {
////                        try {
////                            val autoTime = Settings.Global.getInt(
////                                contentResolver,
////                                Settings.Global.AUTO_TIME,
////                                0
////                            )
////                            val isEnabled = autoTime == 1
////                            android.util.Log.d(
////                                "MainActivity",
////                                "⏰ [AUTO_TIME] Settings.Global.AUTO_TIME = $autoTime → isEnabled=$isEnabled"
////                            )
////                            result.success(isEnabled)
////                        } catch (e: Exception) {
////                            android.util.Log.e("MainActivity", "❌ [AUTO_TIME] Error: ${e.message}")
////                            result.error("AUTO_TIME_ERROR", e.message, null)
////                        }
////                    }
////
////                    "openDateTimeSettings" -> {
////                        try {
////                            val intent = Intent(Settings.ACTION_DATE_SETTINGS)
////                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
////                            startActivity(intent)
////                            result.success(null)
////                        } catch (e: Exception) {
////                            android.util.Log.e(
////                                "MainActivity",
////                                "❌ [AUTO_TIME] Cannot open Date settings: ${e.message}"
////                            )
////                            try {
////                                val fallback = Intent(Settings.ACTION_SETTINGS)
////                                fallback.flags = Intent.FLAG_ACTIVITY_NEW_TASK
////                                startActivity(fallback)
////                            } catch (_: Exception) {}
////                            result.success(null)
////                        }
////                    }
////
////                    else -> result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ LOCATION MONITOR CHANNEL
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                when (call.method) {
////
////                    "startMonitoring" -> {
////                        try {
////                            val intent = Intent(this, LocationMonitorService::class.java)
////                            startForegroundService(intent)
////                            result.success(true)
////                        } catch (e: Exception) {
////                            result.error("START_ERROR", e.message, null)
////                        }
////                    }
////
////                    "stopMonitoring" -> {
////                        try {
////                            val intent = Intent(this, LocationMonitorService::class.java)
////                            stopService(intent)
////                            result.success(true)
////                        } catch (e: Exception) {
////                            result.error("STOP_ERROR", e.message, null)
////                        }
////                    }
////
////                    "isServiceRunning" -> {
////                        val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
////                        val running = manager.getRunningServices(Integer.MAX_VALUE)
////                            .any { it.service.className == LocationMonitorService::class.java.name }
////                        result.success(running)
////                    }
////
////                    "startOvertimeMonitor" -> {
////                        android.util.Log.d("MainActivity", "▶️ [OT] startOvertimeMonitor called from Flutter")
////                        OvertimeMonitorService.start(this)
////                        result.success(true)
////                    }
////
////                    "stopOvertimeMonitor" -> {
////                        android.util.Log.d("MainActivity", "⏹️ [OT] stopOvertimeMonitor called from Flutter")
////                        OvertimeMonitorService.stop(this)
////                        result.success(true)
////                    }
////
////                    "scheduleIntervalSelfieAlarms" -> {
////                        IntervalSelfieAlarmReceiver.scheduleAll(applicationContext)
////                        result.success(true)
////                    }
////
////                    "cancelIntervalSelfieAlarms" -> {
////                        IntervalSelfieAlarmReceiver.cancelAll(applicationContext)
////                        result.success(true)
////                    }
////
////                    "isDeveloperOptionsEnabled" -> {
////                        try {
////                            val devOptions = Settings.Global.getInt(
////                                contentResolver,
////                                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
////                                0
////                            )
////                            val isEnabled = devOptions != 0
////                            android.util.Log.d(
////                                "MainActivity",
////                                "🛠️ [DEV_OPTIONS] DEVELOPMENT_SETTINGS_ENABLED = $devOptions → isEnabled=$isEnabled"
////                            )
////                            result.success(isEnabled)
////                        } catch (e: Exception) {
////                            android.util.Log.e("MainActivity", "❌ [DEV_OPTIONS] Error: ${e.message}")
////                            result.error("DEV_OPTIONS_ERROR", e.message, null)
////                        }
////                    }
////
////                    "openDeveloperSettings" -> {
////                        try {
////                            val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
////                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
////                            startActivity(intent)
////                            result.success(null)
////                        } catch (e: Exception) {
////                            android.util.Log.e(
////                                "MainActivity",
////                                "❌ [DEV_OPTIONS] Cannot open Developer settings: ${e.message}"
////                            )
////                            try {
////                                val fallback = Intent(Settings.ACTION_SETTINGS)
////                                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
////                                startActivity(fallback)
////                            } catch (_: Exception) {}
////                            result.success(null)
////                        }
////                    }
////
////                    else -> result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ MQTT SERVICE CHANNEL (unchanged)
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MQTT_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                when (call.method) {
////                    "startService" -> {
////                        if (hasLocationPermission()) {
////                            val deviceId    = call.argument<String>("deviceId")    ?: ""
////                            val companyCode = call.argument<String>("companyCode") ?: ""
////                            val empName     = call.argument<String>("empName")     ?: ""
////
////                            android.util.Log.d("MainActivity",
////                                "startService → deviceId=$deviceId company=$companyCode emp=$empName")
////
////                            if (deviceId.isNotEmpty() && companyCode.isNotEmpty()) {
////                                LocationMonitorService.start(this, deviceId, companyCode, empName)
////                            } else {
////                                LocationMonitorService.start(this)
////                            }
////                            result.success(null)
////                        } else {
////                            result.error("NO_PERMISSION", "Location permission not granted", null)
////                        }
////                    }
////                    "stopService" -> {
////                        LocationMonitorService.stop(this)
////                        result.success(null)
////                    }
////                    "requestBatteryOptimization" -> {
////                        try {
////                            val pm = getSystemService(POWER_SERVICE) as PowerManager
////                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
////                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
////                                intent.data = Uri.parse("package:$packageName")
////                                startActivity(intent)
////                            }
////                            result.success(null)
////                        } catch (e: Exception) {
////                            result.success(null)
////                        }
////                    }
////                    else -> result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ REAL LOCATION CHANNEL (unchanged)
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.metaxperts/real_location")
////            .setMethodCallHandler { call, result ->
////                if (call.method == "getRealLocation") {
////                    try {
////                        val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
////                        val location = lm.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
////                        if (location != null) {
////                            result.success(mapOf(
////                                "latitude"  to location.latitude,
////                                "longitude" to location.longitude
////                            ))
////                        } else {
////                            result.error("UNAVAILABLE", "Real GPS not available", null)
////                        }
////                    } catch (e: Exception) {
////                        result.error("ERROR", e.message, null)
////                    }
////                } else {
////                    result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ SIM INFO CHANNEL (unchanged)
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                if (call.method == "getSimInfo") {
////                    try {
////                        val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
////                        val subs = subManager.activeSubscriptionInfoList
////                        if (!subs.isNullOrEmpty()) {
////                            val simInfo = subs.mapIndexed { i, info ->
////                                "SIM${i + 1}: ${info.carrierName ?: "Unknown"}"
////                            }.joinToString(", ")
////                            result.success(simInfo)
////                        } else {
////                            result.success("No SIM")
////                        }
////                    } catch (e: Exception) {
////                        result.success("unavailable")
////                    }
////                } else {
////                    result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ TASK NOTIFICATION CHANNEL (unchanged)
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "task_notifications")
////            .setMethodCallHandler { call, result ->
////                if (call.method == "showTaskNotification") {
////                    TaskNotificationService.showNewTaskNotification(
////                        context    = this,
////                        taskTitle  = call.argument<String>("taskTitle")  ?: "",
////                        taskDesc   = call.argument<String>("taskDesc")   ?: "",
////                        assignedBy = call.argument<String>("assignedBy") ?: ""
////                    )
////                    result.success(null)
////                } else {
////                    result.notImplemented()
////                }
////            }
////
////        // ══════════════════════════════════════════════════════════════════
////        // ✅ GPS FRAUD DETECTION CHANNEL
////        // ══════════════════════════════════════════════════════════════════
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GPS_FRAUD_CHANNEL)
////            .setMethodCallHandler { call, result ->
////                when (call.method) {
////                    "getSatelliteCount" -> {
////                        val count = LocationMonitorService.lastSatelliteCount
////                        android.util.Log.d("MainActivity",
////                            "🛰️ [GPS FRAUD] getSatelliteCount → $count")
////                        result.success(count)
////                    }
////                    else -> result.notImplemented()
////                }
////            }
////    }
////
////    private fun hasLocationPermission(): Boolean {
////        return ContextCompat.checkSelfPermission(
////            this, Manifest.permission.ACCESS_FINE_LOCATION
////        ) == PackageManager.PERMISSION_GRANTED ||
////                ContextCompat.checkSelfPermission(
////                    this, Manifest.permission.ACCESS_COARSE_LOCATION
////                ) == PackageManager.PERMISSION_GRANTED
////    }
////}
//
//package com.metaxperts.bookdispatch
//
//import android.Manifest
//import android.content.Context
//import android.content.Intent
//import android.content.pm.PackageManager
//import android.net.Uri
//import android.os.Build
//import android.os.Bundle
//import android.os.PowerManager
//import android.provider.Settings
//import android.telephony.SubscriptionManager
//import androidx.core.content.ContextCompat
//import com.google.android.gms.common.GoogleApiAvailability
//import com.google.android.gms.security.ProviderInstaller
//import com.google.android.play.core.integrity.IntegrityManagerFactory
//import com.google.android.play.core.integrity.IntegrityTokenRequest
//import io.flutter.embedding.android.FlutterFragmentActivity
//import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodChannel
//
//class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
//
//    private val LOCATION_CHANNEL        = "com.metaxperts.bookdispatch/location_monitor"
//    private val MQTT_CHANNEL            = "com.example.untitled2/mqtt_service"
//    private val SIM_CHANNEL             = "sim_info_channel"
//    private val AUTO_TIME_CHANNEL       = "com.metaxperts.bookdispatch/auto_time_check"
//    private val PLAY_INTEGRITY_CHANNEL  = "play_integrity"
//    private val GPS_FRAUD_CHANNEL = "com.metaxperts.bookdispatch/gps_fraud"
//
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        installProvider()
//        GeofenceViolationNotificationService.startService(this)
//        TaskNotificationService.createChannel(this)
//    }
//
//    private fun installProvider() {
//        ProviderInstaller.installIfNeededAsync(this, this)
//    }
//
//    override fun onProviderInstalled() {}
//
//    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//    }
//
//    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//        super.configureFlutterEngine(flutterEngine)
//
//        // ══════════════════════════════════════════════════════════════════
//        // ✅ PLAY INTEGRITY CHANNEL
//        // ══════════════════════════════════════════════════════════════════
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAY_INTEGRITY_CHANNEL)
//            .setMethodCallHandler { call, result ->
//                if (call.method == "getIntegrityToken") {
//                    val cloudProjectNumber = call.argument<String>("cloudProjectNumber")?.toLongOrNull()
//                        ?: run {
//                            result.error("INVALID_ARG", "cloudProjectNumber is required", null)
//                            return@setMethodCallHandler
//                        }
//                    val nonce = call.argument<String>("nonce") ?: java.util.UUID.randomUUID().toString()
//                    val integrityManager = IntegrityManagerFactory.create(applicationContext)
//                    val request = IntegrityTokenRequest.builder()
//                        .setCloudProjectNumber(cloudProjectNumber)
//                        .setNonce(nonce)
//                        .build()
//                    integrityManager.requestIntegrityToken(request)
//                        .addOnSuccessListener { response -> result.success(response.token()) }
//                        .addOnFailureListener { e -> result.error("INTEGRITY_ERROR", e.message, null) }
//                } else {
//                    result.notImplemented()
//                }
//            }
//
//        // ══════════════════════════════════════════════════════════════════
//        // ✅ AUTO TIME CHECK CHANNEL
//        // ══════════════════════════════════════════════════════════════════
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_TIME_CHANNEL)
//            .setMethodCallHandler { call, result ->
//                when (call.method) {
//
//
//                    "isAutoTimeEnabled" -> {
//                        try {
//                            val autoTime = Settings.Global.getInt(
//                                contentResolver,
//                                Settings.Global.AUTO_TIME,
//                                0
//                            )
//                            val isEnabled = autoTime == 1
//                            android.util.Log.d(
//                                "MainActivity",
//                                "⏰ [AUTO_TIME] Settings.Global.AUTO_TIME = $autoTime → isEnabled=$isEnabled"
//                            )
//                            result.success(isEnabled)
//                        } catch (e: Exception) {
//                            android.util.Log.e("MainActivity", "❌ [AUTO_TIME] Error: ${e.message}")
//                            result.error("AUTO_TIME_ERROR", e.message, null)
//                        }
//                    }
//
//                    "openDateTimeSettings" -> {
//                        try {
//                            val intent = Intent(Settings.ACTION_DATE_SETTINGS)
//                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
//                            startActivity(intent)
//                            result.success(null)
//                        } catch (e: Exception) {
//                            android.util.Log.e(
//                                "MainActivity",
//                                "❌ [AUTO_TIME] Cannot open Date settings: ${e.message}"
//                            )
//                            try {
//                                val fallback = Intent(Settings.ACTION_SETTINGS)
//                                fallback.flags = Intent.FLAG_ACTIVITY_NEW_TASK
//                                startActivity(fallback)
//                            } catch (_: Exception) {}
//                            result.success(null)
//                        }
//                    }
//
//                    else -> result.notImplemented()
//                }
//            }
//
//        // ══════════════════════════════════════════════════════════════════
//        // ✅ LOCATION MONITOR CHANNEL
//        // ══════════════════════════════════════════════════════════════════
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
//            .setMethodCallHandler { call, result ->
//                when (call.method) {
//
//                    "startMonitoring" -> {
//                        try {
//                            val intent = Intent(this, LocationMonitorService::class.java)
//                            startForegroundService(intent)
//                            result.success(true)
//                        } catch (e: Exception) {
//                            result.error("START_ERROR", e.message, null)
//                        }
//                    }
//
//                    "stopMonitoring" -> {
//                        try {
//                            val intent = Intent(this, LocationMonitorService::class.java)
//                            stopService(intent)
//                            result.success(true)
//                        } catch (e: Exception) {
//                            result.error("STOP_ERROR", e.message, null)
//                        }
//                    }
//
//                    "isServiceRunning" -> {
//                        val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
//                        val running = manager.getRunningServices(Integer.MAX_VALUE)
//                            .any { it.service.className == LocationMonitorService::class.java.name }
//                        result.success(running)
//                    }
//
//                    "startOvertimeMonitor" -> {
//                        android.util.Log.d("MainActivity", "▶️ [OT] startOvertimeMonitor called from Flutter")
//                        OvertimeMonitorService.start(this)
//                        result.success(true)
//                    }
//
//                    "stopOvertimeMonitor" -> {
//                        android.util.Log.d("MainActivity", "⏹️ [OT] stopOvertimeMonitor called from Flutter")
//                        OvertimeMonitorService.stop(this)
//                        result.success(true)
//                    }
//
//                    "scheduleIntervalSelfieAlarms" -> {
//                        IntervalSelfieAlarmReceiver.scheduleAll(applicationContext)
//                        result.success(true)
//                    }
//
//                    "cancelIntervalSelfieAlarms" -> {
//                        IntervalSelfieAlarmReceiver.cancelAll(applicationContext)
//                        result.success(true)
//                    }
//
//                    "isDeveloperOptionsEnabled" -> {
//                        try {
//                            val devOptions = Settings.Global.getInt(
//                                contentResolver,
//                                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
//                                0
//                            )
//                            val isEnabled = devOptions != 0
//                            android.util.Log.d(
//                                "MainActivity",
//                                "🛠️ [DEV_OPTIONS] DEVELOPMENT_SETTINGS_ENABLED = $devOptions → isEnabled=$isEnabled"
//                            )
//                            result.success(isEnabled)
//                        } catch (e: Exception) {
//                            android.util.Log.e("MainActivity", "❌ [DEV_OPTIONS] Error: ${e.message}")
//                            result.error("DEV_OPTIONS_ERROR", e.message, null)
//                        }
//                    }
//
//                    "openDeveloperSettings" -> {
//                        try {
//                            val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
//                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
//                            startActivity(intent)
//                            result.success(null)
//                        } catch (e: Exception) {
//                            android.util.Log.e(
//                                "MainActivity",
//                                "❌ [DEV_OPTIONS] Cannot open Developer settings: ${e.message}"
//                            )
//                            try {
//                                val fallback = Intent(Settings.ACTION_SETTINGS)
//                                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
//                                startActivity(fallback)
//                            } catch (_: Exception) {}
//                            result.success(null)
//                        }
//                    }
//
//                    // ✅ NEW — Battery Optimization real-time check
//                    "isBatteryOptimizationIgnored" -> {
//                        try {
//                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
//                            val ignored = pm.isIgnoringBatteryOptimizations(packageName)
//                            android.util.Log.d(
//                                "MainActivity",
//                                "🔋 [BATTERY] isIgnoringBatteryOptimizations=$ignored"
//                            )
//                            result.success(ignored)
//                        } catch (e: Exception) {
//                            android.util.Log.e("MainActivity", "❌ [BATTERY] Error: ${e.message}")
//                            result.error("BATTERY_ERROR", e.message, null)
//                        }
//                    }
//
//                    else -> result.notImplemented()
//                }
//            }
//
//        // ══════════════════════════════════════════════════════════════════
//        // ✅ MQTT SERVICE CHANNEL (unchanged)
//        // ══════════════════════════════════════════════════════════════════
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MQTT_CHANNEL)
//            .setMethodCallHandler { call, result ->
//                when (call.method) {
//                    "startService" -> {
//                        if (hasLocationPermission()) {
//                            val deviceId    = call.argument<String>("deviceId")    ?: ""
//                            val companyCode = call.argument<String>("companyCode") ?: ""
//                            val empName     = call.argument<String>("empName")     ?: ""
//
//                            android.util.Log.d("MainActivity",
//                                "startService → deviceId=$deviceId company=$companyCode emp=$empName")
//
//                            if (deviceId.isNotEmpty() && companyCode.isNotEmpty()) {
//                                LocationMonitorService.start(this, deviceId, companyCode, empName)
//                            } else {
//                                LocationMonitorService.start(this)
//                            }
//                            result.success(null)
//                        } else {
//                            result.error("NO_PERMISSION", "Location permission not granted", null)
//                        }
//                    }
//                    "stopService" -> {
//                        LocationMonitorService.stop(this)
//                        result.success(null)
//                    }
//                    "requestBatteryOptimization" -> {
//                        try {
//                            val pm = getSystemService(POWER_SERVICE) as PowerManager
//                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
//                                intent.data = Uri.parse("package:$packageName")
//                                startActivity(intent)
//                            }
//                            result.success(null)
//                        } catch (e: Exception) {
//                            result.success(null)
//                        }
//                    }
//                    else -> result.notImplemented()
//                }
//            }
//
//        // ══════════════════════════════════════════════════════════════════
//        // ✅ REAL LOCATION CHANNEL (unchanged)
//        // ══════════════════════════════════════════════════════════════════
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.metaxperts/real_location")
//            .setMethodCallHandler { call, result ->
//                if (call.method == "getRealLocation") {
//                    try {
//                        val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
//                        val location = lm.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
//                        if (location != null) {
//                            result.success(mapOf(
//                                "latitude"  to location.latitude,
//                                "longitude" to location.longitude
//                            ))
//                        } else {
//                            result.error("UNAVAILABLE", "Real GPS not available", null)
//                        }
//                    } catch (e: Exception) {
//                        result.error("ERROR", e.message, null)
//                    }
//                } else {
//                    result.notImplemented()
//                }
//            }
//
//        // ══════════════════════════════════════════════════════════════════
//        // ✅ SIM INFO CHANNEL (unchanged)
//        // ══════════════════════════════════════════════════════════════════
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_CHANNEL)
//            .setMethodCallHandler { call, result ->
//                if (call.method == "getSimInfo") {
//                    try {
//                        val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
//                        val subs = subManager.activeSubscriptionInfoList
//                        if (!subs.isNullOrEmpty()) {
//                            val simInfo = subs.mapIndexed { i, info ->
//                                "SIM${i + 1}: ${info.carrierName ?: "Unknown"}"
//                            }.joinToString(", ")
//                            result.success(simInfo)
//                        } else {
//                            result.success("No SIM")
//                        }
//                    } catch (e: Exception) {
//                        result.success("unavailable")
//                    }
//                } else {
//                    result.notImplemented()
//                }
//            }
//
//        // ══════════════════════════════════════════════════════════════════
//        // ✅ TASK NOTIFICATION CHANNEL (unchanged)
//        // ══════════════════════════════════════════════════════════════════
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "task_notifications")
//            .setMethodCallHandler { call, result ->
//                if (call.method == "showTaskNotification") {
//                    TaskNotificationService.showNewTaskNotification(
//                        context    = this,
//                        taskTitle  = call.argument<String>("taskTitle")  ?: "",
//                        taskDesc   = call.argument<String>("taskDesc")   ?: "",
//                        assignedBy = call.argument<String>("assignedBy") ?: ""
//                    )
//                    result.success(null)
//                } else {
//                    result.notImplemented()
//                }
//            }
//
//        // ══════════════════════════════════════════════════════════════════
//        // ✅ GPS FRAUD DETECTION CHANNEL (unchanged)
//        // ══════════════════════════════════════════════════════════════════
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GPS_FRAUD_CHANNEL)
//            .setMethodCallHandler { call, result ->
//                when (call.method) {
//                    "getSatelliteCount" -> {
//                        val count = LocationMonitorService.lastSatelliteCount
//                        android.util.Log.d("MainActivity",
//                            "🛰️ [GPS FRAUD] getSatelliteCount → $count")
//                        result.success(count)
//                    }
//                    else -> result.notImplemented()
//                }
//            }
//
//        // ✅ EXIT-REASON (FORCE-STOP) DETECTION — additive, touches nothing above.
//        // Registers channel "com.metaxperts.gwm/exit_reason" so Flutter can read
//        // how the process died last time (force stop vs OEM kill vs crash).
//        ExitReasonPlugin.register(this, flutterEngine)
//    }
//
//
//    private fun hasLocationPermission(): Boolean {
//        return ContextCompat.checkSelfPermission(
//            this, Manifest.permission.ACCESS_FINE_LOCATION
//        ) == PackageManager.PERMISSION_GRANTED ||
//                ContextCompat.checkSelfPermission(
//                    this, Manifest.permission.ACCESS_COARSE_LOCATION
//                ) == PackageManager.PERMISSION_GRANTED
//    }
//}


package com.metaxperts.bookdispatch

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.security.ProviderInstaller
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {

    private val LOCATION_CHANNEL        = "com.metaxperts.bookdispatch/location_monitor"
    private val MQTT_CHANNEL            = "com.example.untitled2/mqtt_service"
    private val SIM_CHANNEL             = "sim_info_channel"
    private val AUTO_TIME_CHANNEL       = "com.metaxperts.bookdispatch/auto_time_check"
    private val PLAY_INTEGRITY_CHANNEL  = "play_integrity"
    private val GPS_FRAUD_CHANNEL = "com.metaxperts.bookdispatch/gps_fraud"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        installProvider()
        GeofenceViolationNotificationService.startService(this)
        TaskNotificationService.createChannel(this)
    }

    private fun installProvider() {
        ProviderInstaller.installIfNeededAsync(this, this)
    }

    override fun onProviderInstalled() {}

    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ══════════════════════════════════════════════════════════════════
        // ✅ PLAY INTEGRITY CHANNEL
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAY_INTEGRITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getIntegrityToken") {
                    val cloudProjectNumber = call.argument<String>("cloudProjectNumber")?.toLongOrNull()
                        ?: run {
                            result.error("INVALID_ARG", "cloudProjectNumber is required", null)
                            return@setMethodCallHandler
                        }
                    val nonce = call.argument<String>("nonce") ?: java.util.UUID.randomUUID().toString()
                    val integrityManager = IntegrityManagerFactory.create(applicationContext)
                    val request = IntegrityTokenRequest.builder()
                        .setCloudProjectNumber(cloudProjectNumber)
                        .setNonce(nonce)
                        .build()
                    integrityManager.requestIntegrityToken(request)
                        .addOnSuccessListener { response -> result.success(response.token()) }
                        .addOnFailureListener { e -> result.error("INTEGRITY_ERROR", e.message, null) }
                } else {
                    result.notImplemented()
                }
            }

        // ══════════════════════════════════════════════════════════════════
        // ✅ AUTO TIME CHECK CHANNEL
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_TIME_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isAutoTimeEnabled" -> {
                        try {
                            val autoTime = Settings.Global.getInt(
                                contentResolver,
                                Settings.Global.AUTO_TIME,
                                0
                            )
                            val isEnabled = autoTime == 1
                            android.util.Log.d(
                                "MainActivity",
                                "⏰ [AUTO_TIME] Settings.Global.AUTO_TIME = $autoTime → isEnabled=$isEnabled"
                            )
                            result.success(isEnabled)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "❌ [AUTO_TIME] Error: ${e.message}")
                            result.error("AUTO_TIME_ERROR", e.message, null)
                        }
                    }

                    "openDateTimeSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_DATE_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            android.util.Log.e(
                                "MainActivity",
                                "❌ [AUTO_TIME] Cannot open Date settings: ${e.message}"
                            )
                            try {
                                val fallback = Intent(Settings.ACTION_SETTINGS)
                                fallback.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(fallback)
                            } catch (_: Exception) {}
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ══════════════════════════════════════════════════════════════════
        // ✅ LOCATION MONITOR CHANNEL
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "startMonitoring" -> {
                        try {
                            val intent = Intent(this, LocationMonitorService::class.java)
                            startForegroundService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("START_ERROR", e.message, null)
                        }
                    }

                    "stopMonitoring" -> {
                        try {
                            val intent = Intent(this, LocationMonitorService::class.java)
                            stopService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("STOP_ERROR", e.message, null)
                        }
                    }

                    "isServiceRunning" -> {
                        val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                        val running = manager.getRunningServices(Integer.MAX_VALUE)
                            .any { it.service.className == LocationMonitorService::class.java.name }
                        result.success(running)
                    }

                    "startOvertimeMonitor" -> {
                        android.util.Log.d("MainActivity", "▶️ [OT] startOvertimeMonitor called from Flutter")
                        OvertimeMonitorService.start(this)
                        result.success(true)
                    }

                    "stopOvertimeMonitor" -> {
                        android.util.Log.d("MainActivity", "⏹️ [OT] stopOvertimeMonitor called from Flutter")
                        OvertimeMonitorService.stop(this)
                        result.success(true)
                    }

                    "scheduleIntervalSelfieAlarms" -> {
                        IntervalSelfieAlarmReceiver.scheduleAll(applicationContext)
                        result.success(true)
                    }

                    "cancelIntervalSelfieAlarms" -> {
                        IntervalSelfieAlarmReceiver.cancelAll(applicationContext)
                        result.success(true)
                    }

                    "isDeveloperOptionsEnabled" -> {
                        try {
                            val devOptions = Settings.Global.getInt(
                                contentResolver,
                                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                                0
                            )
                            val isEnabled = devOptions != 0
                            android.util.Log.d(
                                "MainActivity",
                                "🛠️ [DEV_OPTIONS] DEVELOPMENT_SETTINGS_ENABLED = $devOptions → isEnabled=$isEnabled"
                            )
                            result.success(isEnabled)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "❌ [DEV_OPTIONS] Error: ${e.message}")
                            result.error("DEV_OPTIONS_ERROR", e.message, null)
                        }
                    }

                    "openDeveloperSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            android.util.Log.e(
                                "MainActivity",
                                "❌ [DEV_OPTIONS] Cannot open Developer settings: ${e.message}"
                            )
                            try {
                                val fallback = Intent(Settings.ACTION_SETTINGS)
                                fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(fallback)
                            } catch (_: Exception) {}
                            result.success(null)
                        }
                    }

                    // ✅ NEW — Battery Optimization real-time check
                    "isBatteryOptimizationIgnored" -> {
                        try {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            val ignored = pm.isIgnoringBatteryOptimizations(packageName)
                            android.util.Log.d(
                                "MainActivity",
                                "🔋 [BATTERY] isIgnoringBatteryOptimizations=$ignored"
                            )
                            result.success(ignored)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "❌ [BATTERY] Error: ${e.message}")
                            result.error("BATTERY_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ══════════════════════════════════════════════════════════════════
        // ✅ MQTT SERVICE CHANNEL - ADDED getBatteryMode HANDLER
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MQTT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        if (hasLocationPermission()) {
                            val deviceId    = call.argument<String>("deviceId")    ?: ""
                            val companyCode = call.argument<String>("companyCode") ?: ""
                            val empName     = call.argument<String>("empName")     ?: ""

                            android.util.Log.d("MainActivity",
                                "startService → deviceId=$deviceId company=$companyCode emp=$empName")

                            if (deviceId.isNotEmpty() && companyCode.isNotEmpty()) {
                                LocationMonitorService.start(this, deviceId, companyCode, empName)
                            } else {
                                LocationMonitorService.start(this)
                            }
                            result.success(null)
                        } else {
                            result.error("NO_PERMISSION", "Location permission not granted", null)
                        }
                    }
                    "stopService" -> {
                        LocationMonitorService.stop(this)
                        result.success(null)
                    }
                    "requestBatteryOptimization" -> {
                        try {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    // ▼▼▼ ADD THIS: BATTERY MODE DETECTION ▼▼▼
                    "getBatteryMode" -> {
                        android.util.Log.d("MainActivity", "🔋 getBatteryMode called from Flutter")
                        try {
                            val mode = BatteryModeHelper.getBatteryMode(this)
                            android.util.Log.d("MainActivity", "🔋 getBatteryMode result → $mode")
                            result.success(mode)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "❌ getBatteryMode error: ${e.message}")
                            result.success("OPTIMIZED")
                        }
                    }
                    // ▲▲▲ BATTERY MODE HANDLER ENDS ▲▲▲
                    else -> result.notImplemented()
                }
            }

        // ══════════════════════════════════════════════════════════════════
        // ✅ REAL LOCATION CHANNEL (unchanged)
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.metaxperts/real_location")
            .setMethodCallHandler { call, result ->
                if (call.method == "getRealLocation") {
                    try {
                        val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
                        val location = lm.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
                        if (location != null) {
                            result.success(mapOf(
                                "latitude"  to location.latitude,
                                "longitude" to location.longitude
                            ))
                        } else {
                            result.error("UNAVAILABLE", "Real GPS not available", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // ══════════════════════════════════════════════════════════════════
        // ✅ SIM INFO CHANNEL (unchanged)
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getSimInfo") {
                    try {
                        val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                        val subs = subManager.activeSubscriptionInfoList
                        if (!subs.isNullOrEmpty()) {
                            val simInfo = subs.mapIndexed { i, info ->
                                "SIM${i + 1}: ${info.carrierName ?: "Unknown"}"
                            }.joinToString(", ")
                            result.success(simInfo)
                        } else {
                            result.success("No SIM")
                        }
                    } catch (e: Exception) {
                        result.success("unavailable")
                    }
                } else {
                    result.notImplemented()
                }
            }

        // ══════════════════════════════════════════════════════════════════
        // ✅ TASK NOTIFICATION CHANNEL (unchanged)
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "task_notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "showTaskNotification") {
                    TaskNotificationService.showNewTaskNotification(
                        context    = this,
                        taskTitle  = call.argument<String>("taskTitle")  ?: "",
                        taskDesc   = call.argument<String>("taskDesc")   ?: "",
                        assignedBy = call.argument<String>("assignedBy") ?: ""
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // ══════════════════════════════════════════════════════════════════
        // ✅ GPS FRAUD DETECTION CHANNEL (unchanged)
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GPS_FRAUD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSatelliteCount" -> {
                        val count = LocationMonitorService.lastSatelliteCount
                        android.util.Log.d("MainActivity",
                            "🛰️ [GPS FRAUD] getSatelliteCount → $count")
                        result.success(count)
                    }
                    else -> result.notImplemented()
                }
            }

        // ✅ EXIT-REASON (FORCE-STOP) DETECTION
        ExitReasonPlugin.register(this, flutterEngine)
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                    this, Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
    }
}