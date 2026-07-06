//package com.metaxperts.GPS_Workforce_Monitor
//
//import android.app.ActivityManager
//import android.content.Context
//import android.os.Build
//import android.os.PowerManager
//
//object BatteryModeHelper {
//
//    /// Returns one of: "UNRESTRICTED", "RESTRICTED", "OPTIMIZED"
//    fun getBatteryMode(context: Context): String {
//        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
//        val isIgnoringOptimizations = pm.isIgnoringBatteryOptimizations(context.packageName)
//
//        if (isIgnoringOptimizations) {
//            // App battery optimization se whitelisted hai
//            return "UNRESTRICTED"
//        }
//
//        // Android 9+ (API 28+) explicit "Restricted" bucket expose karta hai.
//        // Reflection use kar rahe hain taake minSdkVersion/compileSdk 28 se
//        // kam hone par bhi ye file compile ho jaye.
//        if (Build.VERSION.SDK_INT >= 28) {
//            try {
//                val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
//                if (am != null) {
//                    val method = ActivityManager::class.java.getMethod("getAppStandbyBucket")
//                    val bucket = method.invoke(am) as? Int ?: 0
//                    if (bucket == 45 /* APP_STANDBY_BUCKET_RESTRICTED */) {
//                        return "RESTRICTED"
//                    }
//                }
//            } catch (e: Exception) {
//                android.util.Log.e("BatteryModeHelper", "appStandbyBucket check failed: ${e.message}")
//            }
//        }
//
//        // Na whitelisted, na explicitly restricted → default OS optimization
//        return "OPTIMIZED"
//    }
//}

package com.metaxperts.GPS_Workforce_Monitor

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager

object BatteryModeHelper {

    /// Returns one of: "UNRESTRICTED", "RESTRICTED", "OPTIMIZED"
    fun getBatteryMode(context: Context): String {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val isIgnoringOptimizations = pm.isIgnoringBatteryOptimizations(context.packageName)

        // ✅ First check: Is app whitelisted? → UNRESTRICTED
        if (isIgnoringOptimizations) {
            return "UNRESTRICTED"
        }

        // ✅ Second check: Android 9+ standby bucket via ActivityManager
        if (Build.VERSION.SDK_INT >= 28) {
            try {
                val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

                // Method 1: Try getAppStandbyBucket() - this sometimes fails on some devices
                try {
                    val method = ActivityManager::class.java.getMethod("getAppStandbyBucket")
                    val bucket = method.invoke(am) as? Int ?: 0
                    if (bucket == 45 /* APP_STANDBY_BUCKET_RESTRICTED */) {
                        return "RESTRICTED"
                    }
                } catch (e: Exception) {
                    android.util.Log.w("BatteryModeHelper", "getAppStandbyBucket failed: ${e.message}")
                }

                // ✅ Method 2: Try getAppStandbyBucketForPackage() - more reliable
                try {
                    val method = ActivityManager::class.java.getMethod(
                        "getAppStandbyBucketForPackage",
                        String::class.java
                    )
                    val bucket = method.invoke(am, context.packageName) as? Int ?: 0
                    android.util.Log.d("BatteryModeHelper", "getAppStandbyBucketForPackage returned: $bucket")
                    if (bucket == 45) {
                        return "RESTRICTED"
                    }
                } catch (e: Exception) {
                    android.util.Log.w("BatteryModeHelper", "getAppStandbyBucketForPackage failed: ${e.message}")
                }

                // ✅ Method 3: Check usage stats for recent background restriction
                try {
                    val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
                            as? android.app.usage.UsageStatsManager

                    if (usageStatsManager != null) {
                        // Get standby bucket via UsageStatsManager (API 28+)
                        val method = usageStatsManager.javaClass.getMethod(
                            "getAppStandbyBucketForPackage",
                            String::class.java
                        )
                        val bucket = method.invoke(usageStatsManager, context.packageName) as? Int ?: 0
                        android.util.Log.d("BatteryModeHelper", "UsageStatsManager bucket: $bucket")
                        if (bucket == 45) {
                            return "RESTRICTED"
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.w("BatteryModeHelper", "UsageStatsManager check failed: ${e.message}")
                }

                // ✅ Method 4: Check if app is in power save mode
                try {
                    val isPowerSaveMode = pm.isPowerSaveMode
                    android.util.Log.d("BatteryModeHelper", "isPowerSaveMode: $isPowerSaveMode")
                    if (isPowerSaveMode) {
                        return "RESTRICTED"
                    }
                } catch (e: Exception) {
                    android.util.Log.w("BatteryModeHelper", "isPowerSaveMode check failed: ${e.message}")
                }

            } catch (e: Exception) {
                android.util.Log.e("BatteryModeHelper", "Overall check failed: ${e.message}")
            }
        }

        // ✅ Third check: Android 6+ (API 23) Doze mode
        if (Build.VERSION.SDK_INT >= 23) {
            try {
                val isDeviceIdleMode = pm.isDeviceIdleMode
                android.util.Log.d("BatteryModeHelper", "isDeviceIdleMode: $isDeviceIdleMode")
                if (isDeviceIdleMode) {
                    return "RESTRICTED"
                }
            } catch (e: Exception) {
                android.util.Log.w("BatteryModeHelper", "isDeviceIdleMode check failed: ${e.message}")
            }
        }

        // Neither whitelisted, nor explicitly restricted → default optimized
        return "OPTIMIZED"
    }
}