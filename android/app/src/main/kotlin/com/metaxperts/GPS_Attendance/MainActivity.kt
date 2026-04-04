////package com.metaxperts.GPS_Workforce_Monitor
////
////import android.content.Intent
////import android.os.Bundle
////import com.google.android.gms.common.GoogleApiAvailability
////import com.google.android.gms.security.ProviderInstaller
////import io.flutter.embedding.android.FlutterActivity
////
////class MainActivity : FlutterActivity(), ProviderInstaller.ProviderInstallListener {
////
////    override fun onCreate(savedInstanceState: Bundle?) {
////        super.onCreate(savedInstanceState)
////        installProvider()
////    }
////
////    private fun installProvider() {
////        ProviderInstaller.installIfNeededAsync(this, this)
////    }
////
////    override fun onProviderInstalled() {
////        // Provider installed successfully
////    }
////
////    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
////        // Provider installation failed, handle the error here
////        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
////    }
////}
////
//
//package com.metaxperts.GPS_Workforce_Monitor
//
//import android.content.Intent
//import android.os.Bundle
//import com.google.android.gms.common.GoogleApiAvailability
//import com.google.android.gms.security.ProviderInstaller
//import io.flutter.embedding.android.FlutterActivity
//import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodChannel
//
//class MainActivity : FlutterActivity(), ProviderInstaller.ProviderInstallListener {
//
//    private val CHANNEL = "com.metaxperts.GPS_Workforce_Monitor/location_monitor"
//
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//        installProvider()
//    }
//
//    private fun installProvider() {
//        ProviderInstaller.installIfNeededAsync(this, this)
//    }
//
//    override fun onProviderInstalled() {
//        // Provider installed successfully
//    }
//
//    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
//        // Provider installation failed, handle the error here
//        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
//    }
//
//    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//        super.configureFlutterEngine(flutterEngine)
//
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
//                else -> {
//                    result.notImplemented()
//                }
//            }
//        }
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
import androidx.core.content.ContextCompat
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.security.ProviderInstaller
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), ProviderInstaller.ProviderInstallListener {

    private val LOCATION_CHANNEL = "com.metaxperts.GPS_Workforce_Monitor/location_monitor"
    private val MQTT_CHANNEL = "com.example.untitled2/mqtt_service"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        installProvider()
    }

    private fun installProvider() {
        ProviderInstaller.installIfNeededAsync(this, this)
    }

    override fun onProviderInstalled() {
        // Provider installed successfully
    }

    override fun onProviderInstallFailed(errorCode: Int, intent: Intent?) {
        // Provider installation failed, handle the error here
        GoogleApiAvailability.getInstance().showErrorNotification(this, errorCode)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ LOCATION MONITOR CHANNEL
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
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
                else -> {
                    result.notImplemented()
                }
            }
        }

        // ✅ MQTT SERVICE CHANNEL
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MQTT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    if (hasLocationPermission()) {
                        LocationMonitorService.start(this)
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

        // ✅ REAL LOCATION CHANNEL (bypasses mock GPS)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.metaxperts/real_location").setMethodCallHandler { call, result ->
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