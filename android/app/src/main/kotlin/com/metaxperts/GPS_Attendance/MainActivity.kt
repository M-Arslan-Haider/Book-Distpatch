//package com.metaxperts.GPS_Workforce_Monitor
//
//import android.content.Intent
//import android.os.Bundle
//import com.google.android.gms.common.GoogleApiAvailability
//import com.google.android.gms.security.ProviderInstaller
//import io.flutter.embedding.android.FlutterActivity
//
//class MainActivity : FlutterActivity(), ProviderInstaller.ProviderInstallListener {
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
//}
//

package com.metaxperts.GPS_Workforce_Monitor

import android.content.Intent
import android.os.Bundle
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.security.ProviderInstaller
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), ProviderInstaller.ProviderInstallListener {

    private val CHANNEL = "com.metaxperts.GPS_Workforce_Monitor/location_monitor"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
    }
}