//package com.metaxperts.GPS_Workforce_Monitor
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
//// ✅ BIOMETRIC: FlutterFragmentActivity is required by local_auth so the
////    Android BiometricPrompt can attach to a FragmentActivity.
////    FlutterActivity does NOT extend FragmentActivity, so the biometric
////    bottom-sheet would crash at runtime without this change.
//import io.flutter.embedding.android.FlutterFragmentActivity   // ← CHANGED
//import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodChannel
//
//// ✅ BIOMETRIC: extend FlutterFragmentActivity instead of FlutterActivity
//class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {
//
//    private val LOCATION_CHANNEL = "com.metaxperts.GPS_Workforce_Monitor/location_monitor"
//    private val MQTT_CHANNEL = "com.example.untitled2/mqtt_service"
//    private val SIM_CHANNEL = "sim_info_channel"
//
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        installProvider()
//
//        // ✅ GEOFENCE VIOLATION NOTIFICATIONS — start background watcher
//        // This is the ONLY addition. No other logic is changed.
//        GeofenceViolationNotificationService.startService(this)
//
//        // ✅ TASK NOTIFICATION CHANNEL — register notification channel
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
//        // ✅ LOCATION MONITOR CHANNEL
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
//            when (call.method) {
//                "startMonitoring" -> {
//                    try {
//                        val intent = Intent(this, LocationMonitorService::class.java)
//                        startForegroundService(intent)
//                        result.success(true)
//                    } catch (e: Exception) {
//                        result.error("START_ERROR", e.message, null)
//                    }
//                }
//                "stopMonitoring" -> {
//                    try {
//                        val intent = Intent(this, LocationMonitorService::class.java)
//                        stopService(intent)
//                        result.success(true)
//                    } catch (e: Exception) {
//                        result.error("STOP_ERROR", e.message, null)
//                    }
//                }
//                "isServiceRunning" -> {
//                    val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
//                    val running = manager.getRunningServices(Integer.MAX_VALUE)
//                        .any { it.service.className == LocationMonitorService::class.java.name }
//                    result.success(running)
//                }
//                "startOvertimeMonitor" -> {
//                    android.util.Log.d("MainActivity", "▶️ [OT] startOvertimeMonitor called from Flutter")
//                    OvertimeMonitorService.start(this)
//                    result.success(true)
//                }
//                "stopOvertimeMonitor" -> {
//                    android.util.Log.d("MainActivity", "⏹️ [OT] stopOvertimeMonitor called from Flutter")
//                    OvertimeMonitorService.stop(this)
//                    result.success(true)
//                }
//                // ✅ INTERVAL SELFIE ALARMS
//                "scheduleIntervalSelfieAlarms" -> {
//                    IntervalSelfieAlarmReceiver.scheduleAll(applicationContext)
//                    result.success(true)
//                }
//                "cancelIntervalSelfieAlarms" -> {
//                    IntervalSelfieAlarmReceiver.cancelAll(applicationContext)
//                    result.success(true)
//                }
//                else -> result.notImplemented()
//            }
//        }
//
//        // ✅ MQTT SERVICE CHANNEL
//        // FIX: "startService" now reads deviceId / companyCode / empName
//        //      from the MethodChannel arguments and passes them as Intent
//        //      extras to LocationMonitorService. Previously these were
//        //      ignored, so the service started with empty identity and
//        //      published to topic "gps//" instead of "gps/{company}/{user}".
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MQTT_CHANNEL).setMethodCallHandler { call, result ->
//            when (call.method) {
//                "startService" -> {
//                    if (hasLocationPermission()) {
//                        // ── FIX #1: Extract identity from Dart arguments ──
//                        val deviceId    = call.argument<String>("deviceId") ?: ""
//                        val companyCode = call.argument<String>("companyCode") ?: ""
//                        val empName     = call.argument<String>("empName") ?: ""
//
//                        android.util.Log.d("MainActivity",
//                            "startService → deviceId=$deviceId company=$companyCode emp=$empName")
//
//                        // Pass identity to the service via the overloaded start()
//                        if (deviceId.isNotEmpty() && companyCode.isNotEmpty()) {
//                            LocationMonitorService.start(this, deviceId, companyCode, empName)
//                        } else {
//                            // Fallback: start without extras (service reads from SharedPreferences)
//                            LocationMonitorService.start(this)
//                        }
//                        result.success(null)
//                    } else {
//                        result.error("NO_PERMISSION", "Location permission not granted", null)
//                    }
//                }
//                "stopService" -> {
//                    LocationMonitorService.stop(this)
//                    result.success(null)
//                }
//                "requestBatteryOptimization" -> {
//                    try {
//                        val pm = getSystemService(POWER_SERVICE) as PowerManager
//                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
//                            intent.data = Uri.parse("package:$packageName")
//                            startActivity(intent)
//                        }
//                        result.success(null)
//                    } catch (e: Exception) {
//                        result.success(null)
//                    }
//                }
//                else -> result.notImplemented()
//            }
//        }
//
//        // ✅ REAL LOCATION CHANNEL (bypasses mock GPS)
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.metaxperts/real_location").setMethodCallHandler { call, result ->
//            if (call.method == "getRealLocation") {
//                try {
//                    val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
//                    val location = lm.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
//                    if (location != null) {
//                        result.success(mapOf(
//                            "latitude"  to location.latitude,
//                            "longitude" to location.longitude
//                        ))
//                    } else {
//                        result.error("UNAVAILABLE", "Real GPS not available", null)
//                    }
//                } catch (e: Exception) {
//                    result.error("ERROR", e.message, null)
//                }
//            } else {
//                result.notImplemented()
//            }
//        }
//
//        // ✅ SIM INFO CHANNEL
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_CHANNEL).setMethodCallHandler { call, result ->
//            if (call.method == "getSimInfo") {
//                try {
//                    val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
//                    val subs = subManager.activeSubscriptionInfoList
//                    if (!subs.isNullOrEmpty()) {
//                        val simInfo = subs.mapIndexed { i, info ->
//                            "SIM${i + 1}: ${info.carrierName ?: "Unknown"}"
//                        }.joinToString(", ")
//                        result.success(simInfo)
//                    } else {
//                        result.success("No SIM")
//                    }
//                } catch (e: Exception) {
//                    result.success("unavailable")
//                }
//            } else {
//                result.notImplemented()
//            }
//        }
//
//        // ✅ TASK NOTIFICATION CHANNEL
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
//    }
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


package com.metaxperts.GPS_Workforce_Monitor

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
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity(), ProviderInstaller.ProviderInstallListener {

    private val LOCATION_CHANNEL = "com.metaxperts.GPS_Workforce_Monitor/location_monitor"
    private val MQTT_CHANNEL     = "com.example.untitled2/mqtt_service"
    private val SIM_CHANNEL      = "sim_info_channel"

    // ✅ AUTO TIME CHECK — Automatic Date & Time check karne ka channel
    private val AUTO_TIME_CHANNEL = "com.metaxperts.GPS_Workforce_Monitor/auto_time_check"

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
        // ✅ AUTO TIME CHECK CHANNEL
        // Flutter se "isAutoTimeEnabled" call aata hai
        // Android Settings.Global.AUTO_TIME read karta hai:
        //   1 → Automatic Date & Time ON  → true return karo
        //   0 → Automatic Date & Time OFF → false return karo
        //
        // Flutter se "openDateTimeSettings" call aata hai
        // User ko Date & Time settings screen par bhejta hai
        // ══════════════════════════════════════════════════════════════════
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_TIME_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isAutoTimeEnabled" -> {
                        try {
                            // Settings.Global.AUTO_TIME:
                            //   1 = Automatic Date & Time ON
                            //   0 = Automatic Date & Time OFF
                            val autoTime = Settings.Global.getInt(
                                contentResolver,
                                Settings.Global.AUTO_TIME,
                                0  // default: 0 (OFF) agar setting milti nahi
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
                            // User ko Date & Time settings screen par bhejo
                            val intent = Intent(Settings.ACTION_DATE_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            android.util.Log.e(
                                "MainActivity",
                                "❌ [AUTO_TIME] Cannot open Date settings: ${e.message}"
                            )
                            // Fallback: General settings kholo
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

        // ── LOCATION MONITOR CHANNEL (unchanged) ─────────────────────────────
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
                    else -> result.notImplemented()
                }
            }

        // ── MQTT SERVICE CHANNEL (unchanged) ─────────────────────────────────
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
                    else -> result.notImplemented()
                }
            }

        // ── REAL LOCATION CHANNEL (unchanged) ────────────────────────────────
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

        // ── SIM INFO CHANNEL (unchanged) ─────────────────────────────────────
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

        // ── TASK NOTIFICATION CHANNEL (unchanged) ────────────────────────────
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