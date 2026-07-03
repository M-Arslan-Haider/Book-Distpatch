package com.metaxperts.GPS_Workforce_Monitor

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * ExitReasonPlugin
 * ─────────────────────────────────────────────────────────────────────────
 * Purely ADDITIVE. Reads the OS "coroner's report" of how the app process
 * died last time, so the server can distinguish a deliberate FORCE STOP
 * from an OEM/system kill, a crash, or a reboot.
 *
 * It does NOT prevent anything and does NOT touch any existing service.
 * Flutter calls channel method "getExitReasons" on every app launch.
 *
 * NOTE: getHistoricalProcessExitReasons requires Android 11 (API 30+).
 * On older devices it returns an empty list — handle as "unknown" in Dart.
 */
object ExitReasonPlugin {

    private const val CHANNEL = "com.metaxperts.gwm/exit_reason"

    /** Call once from MainActivity.configureFlutterEngine(flutterEngine). */
    fun register(context: Context, flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getExitReasons" -> {
                    try {
                        val max = (call.argument<Int>("max")) ?: 5
                        result.success(getExitReasons(context, max))
                    } catch (e: Exception) {
                        result.error("EXIT_REASON_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Returns a list of maps, most-recent death first. Each map:
     *   reason        : Int    (raw ApplicationExitInfo.reason)
     *   reasonText    : String (human label)
     *   isForceStop   : Bool   (true only for REASON_USER_REQUESTED)
     *   isUserFault   : Bool   (deliberate user action: force stop)
     *   isSystemKill  : Bool   (LOW_MEMORY / SIGNALED / etc — NOT user's fault)
     *   isAppFault    : Bool   (CRASH / ANR — your bug, not the employee)
     *   timestamp     : Long   (epoch millis when the process died)
     *   description   : String (extra OEM detail, may be empty)
     *   importance    : Int    (process importance at death; foreground vs bg)
     */
    private fun getExitReasons(context: Context, max: Int): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            // API < 30: API unavailable. Empty list => Dart treats as "unknown".
            return emptyList()
        }

        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val infos: List<ApplicationExitInfo> =
            am.getHistoricalProcessExitReasons(context.packageName, 0, max)

        return infos.map { info ->
            val reason = info.reason
            mapOf(
                "reason" to reason,
                "reasonText" to reasonToText(reason),
                "isForceStop" to (reason == ApplicationExitInfo.REASON_USER_REQUESTED),
                "isUserFault" to (reason == ApplicationExitInfo.REASON_USER_REQUESTED ||
                        reason == ApplicationExitInfo.REASON_USER_STOPPED),
                "isSystemKill" to (reason == ApplicationExitInfo.REASON_LOW_MEMORY ||
                        reason == ApplicationExitInfo.REASON_SIGNALED ||
                        reason == ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE ||
                        reason == ApplicationExitInfo.REASON_PERMISSION_CHANGE ||
                        reason == ApplicationExitInfo.REASON_DEPENDENCY_DIED ||
                        reason == ApplicationExitInfo.REASON_OTHER),
                "isAppFault" to (reason == ApplicationExitInfo.REASON_CRASH ||
                        reason == ApplicationExitInfo.REASON_CRASH_NATIVE ||
                        reason == ApplicationExitInfo.REASON_ANR ||
                        reason == ApplicationExitInfo.REASON_INITIALIZATION_FAILURE),
                "timestamp" to info.timestamp,
                "description" to (info.description ?: ""),
                "importance" to info.importance
            )
        }
    }

    private fun reasonToText(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_USER_REQUESTED         -> "FORCE_STOP (user requested)"
        ApplicationExitInfo.REASON_USER_STOPPED           -> "USER_STOPPED"
        ApplicationExitInfo.REASON_LOW_MEMORY             -> "LOW_MEMORY (system killed)"
        ApplicationExitInfo.REASON_SIGNALED               -> "SIGNALED (OEM/system kill)"
        ApplicationExitInfo.REASON_CRASH                  -> "CRASH (app bug)"
        ApplicationExitInfo.REASON_CRASH_NATIVE           -> "CRASH_NATIVE (app bug)"
        ApplicationExitInfo.REASON_ANR                    -> "ANR (app not responding)"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INIT_FAILURE"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE      -> "PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED        -> "DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_EXIT_SELF              -> "EXIT_SELF (graceful)"
        ApplicationExitInfo.REASON_OTHER                  -> "OTHER"
        ApplicationExitInfo.REASON_UNKNOWN                -> "UNKNOWN"
        else                                              -> "CODE_$reason"
    }
}
