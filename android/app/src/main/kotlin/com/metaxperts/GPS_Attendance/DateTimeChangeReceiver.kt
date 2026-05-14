package com.metaxperts.GPS_Workforce_Monitor

// ══════════════════════════════════════════════════════════════════════════════
// DateTimeChangeReceiver.kt
//
// PURPOSE:
//   Detects when the user manually changes the device date or time (from
//   Android Settings).  Works in THREE states:
//     1. App in foreground
//     2. App in background
//     3. App fully killed / process dead
//
// HOW IT WORKS:
//   ACTION_TIME_CHANGED  → fires when user changes device time
//   ACTION_DATE_CHANGED  → fires when user changes device date
//   Both are exempt from Android 8+ implicit-broadcast restrictions, so they
//   can be declared in AndroidManifest.xml and will fire even when the app is
//   completely killed.
//
// MANIFEST REGISTRATION (add inside <application> tag in AndroidManifest.xml):
// ─────────────────────────────────────────────────────────────────────────────
//   <receiver
//       android:name=".DateTimeChangeReceiver"
//       android:exported="true">
//       <intent-filter>
//           <action android:name="android.intent.action.TIME_SET" />
//           <action android:name="android.intent.action.DATE_CHANGED" />
//       </intent-filter>
//   </receiver>
// ─────────────────────────────────────────────────────────────────────────────
//
// FIX SUMMARY (why emp_name / company_code / device_id were empty):
//   • emp_name   — Flutter never writes emp_name to SharedPreferences.
//                  Only LocationMonitorService wrote it (as "emp_name", no prefix)
//                  when it started.  If the service had not run yet, the key was
//                  missing.  FIX: parse it from the cached employee JSON that
//                  Flutter DOES write → flutter.cached_employees_{companyCode}.
//
//   • company_code — Flutter writes the company code as
//                  "cached_employees_company" (→ flutter.cached_employees_company).
//                  The old list did not include this key.  FIX: add it as the
//                  first entry in the lookup list.
//
//   • device_id  — Flutter never writes the Android device ID to SharedPreferences.
//                  Only LocationMonitorService wrote it (as "user_name", no prefix).
//                  FIX: read it directly from Settings.Secure.ANDROID_ID — no
//                  dependency on LocationMonitorService at all.
//
// API PAYLOAD COLUMNS:
//   emp_id          — Employee ID (from SharedPreferences)
//   emp_name        — Employee Name (resolved from cached employee JSON)
//   company_code    — Company Code
//   device_id       — Android Settings.Secure.ANDROID_ID
//   dep_id          — Department ID
//   change_type     — "TIME_SET", "TIME_CHANGED", or "DATE_CHANGED"
//   detected_at     — Actual current timestamp when change was detected (system time after broadcast)
//   new_date        — Newly set date that user changed to (yyyy-MM-dd)
//   new_time        — Newly set time that user changed to (HH:mm:ss)
//   battery_percent — Device battery level at time of detection
//   device_model    — Android device model name
//   android_version — Android OS version
//   app_version     — Hard-coded app version string
// ══════════════════════════════════════════════════════════════════════════════

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DateTimeChangeReceiver : BroadcastReceiver() {

    // ── Configuration ──────────────────────────────────────────────────────
    private val API_URL     = "http://oracle.metaxperts.net/ords/gps_workforce/datetimechange/post/"
    private val APP_VERSION = "2.3"
    private val PREFS_NAME  = "FlutterSharedPreferences"
    private val TAG         = "DateTimeChangeReceiver"

    // ── Entry point ────────────────────────────────────────────────────────
    override fun onReceive(context: Context, intent: Intent?) {
        android.util.Log.d(TAG, "📣 onReceive() fired — action=${intent?.action ?: "null"}")

        // Capture detection timestamp immediately when broadcast is received
        // This is the ACTUAL current timestamp when the change was detected
        val detectedAt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())

        val action = intent?.action ?: run {
            android.util.Log.w(TAG, "⚠️ Intent or action is null — ignoring")
            return
        }

        val isTimeSet     = (action == "android.intent.action.TIME_SET")
        val isTimeChanged = (action == Intent.ACTION_TIME_CHANGED)
        val isDateChanged = (action == "android.intent.action.DATE_CHANGED")

        if (!isTimeSet && !isTimeChanged && !isDateChanged) {
            android.util.Log.d(TAG, "ℹ️ Action '$action' is not a date/time change — ignoring")
            return
        }

        val changeType = when {
            isTimeSet     -> "TIME_SET"
            isTimeChanged -> "TIME_CHANGED"
            isDateChanged -> "DATE_CHANGED"
            else          -> return
        }

        android.util.Log.d(TAG, "🕐 [$changeType] Device date/time was manually changed by user")

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // ── DEBUG: dump every key so we can verify exact key names ────────
        // Snapshot into Map<String, *> first — indexing a Map never calls getString,
        // avoiding ClassCastException when a key holds a Long/Int/Boolean value.
        val allPrefs: Map<String, *> = prefs.all
        android.util.Log.d(TAG, "🗃️ [$changeType] ===== ALL SharedPreferences keys =====")
        allPrefs.entries.sortedBy { it.key }.forEach { (k, v) ->
            android.util.Log.d(TAG, "🗃️   '$k'  =  '$v'")
        }
        android.util.Log.d(TAG, "🗃️ [$changeType] ===== END SharedPreferences keys =====")

        // ── emp_id (unchanged — already working) ──────────────────────────
        val empId = firstNonEmpty(prefs, listOf(
            "flutter.emp_id", "emp_id", "flutter.empId", "empId",
            "flutter.user_id", "user_id"
        ))
        android.util.Log.d(TAG, "👤 [$changeType] emp_id='$empId'")

        // ── company_code ──────────────────────────────────────────────────
        // FIX: Flutter explicitly writes prefs.setString('cached_employees_company', companyCode)
        //      which is stored as 'flutter.cached_employees_company' in Android SharedPreferences.
        //      This key is ALWAYS written when employees are fetched — even before
        //      LocationMonitorService has ever started.  Added as the first entry.
        val companyCode = firstNonEmpty(prefs, listOf(
            "flutter.cached_employees_company",  // ← FIX: written by Flutter on every employee fetch
            "flutter.company_code",              // written by Flutter if prefCompanyCode = 'company_code'
            "company_code",                      // written by LocationMonitorService (no prefix)
            "flutter.cached_company_code"
        ))
        android.util.Log.d(TAG, "🏢 [$changeType] company_code='$companyCode'")

        // ── emp_name ──────────────────────────────────────────────────────
        // FIX: Flutter never writes emp_name to SharedPreferences directly.
        //      Only LocationMonitorService wrote it (as "emp_name", no flutter prefix)
        //      when the service started.  If the service had not run, the key was absent.
        //
        //      Flutter DOES write the full employee list as JSON:
        //        prefs.setString('cached_employees_$companyCode', jsonEncode(items))
        //        → stored as 'flutter.cached_employees_{companyCode}'
        //
        //      We look up the employee name from that JSON using the emp_id we already have.
        //      Fall back to the old key lookups so behaviour is unchanged when the service
        //      has already written those keys.
        var empName = firstNonEmpty(prefs, listOf(
            "flutter.emp_name",  // written by LocationMonitorService (with flutter prefix)
            "emp_name"           // written by LocationMonitorService (no prefix)
        ))

        if (empName.isEmpty() && empId.isNotEmpty() && companyCode.isNotEmpty()) {
            empName = resolveEmpNameFromCache(prefs, empId, companyCode, changeType)
        }
        android.util.Log.d(TAG, "👤 [$changeType] emp_name='$empName'")

        // ── device_id ─────────────────────────────────────────────────────
        // FIX: Flutter never writes the Android device ID to SharedPreferences.
        //      Only LocationMonitorService wrote it (as "user_name", no flutter prefix).
        //      If the service had not run, the key was absent.
        //
        //      Read Settings.Secure.ANDROID_ID directly — always available,
        //      no dependency on LocationMonitorService at all.
        var deviceId = firstNonEmpty(prefs, listOf(
            "flutter.user_name",  // written by LocationMonitorService (with flutter prefix)
            "user_name"           // written by LocationMonitorService (no prefix)
        ))

        if (deviceId.isEmpty()) {
            deviceId = try {
                val id = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: ""
                android.util.Log.d(TAG, "📱 [$changeType] device_id resolved from Settings.Secure.ANDROID_ID='$id'")
                id
            } catch (e: Exception) {
                android.util.Log.w(TAG, "⚠️ [$changeType] Could not read ANDROID_ID: ${e.message}")
                ""
            }
        }
        android.util.Log.d(TAG, "📱 [$changeType] device_id='$deviceId'")

        // ── dep_id (unchanged — already working) ──────────────────────────
        val depId = firstNonEmpty(prefs, listOf(
            "flutter.cached_dep_id", "cached_dep_id", "dep_id"
        ))
        android.util.Log.d(TAG, "🏬 [$changeType] dep_id='$depId'")

        // Skip if we have no employee identity at all (user never logged in)
        if (empId.isEmpty() && companyCode.isEmpty()) {
            android.util.Log.w(TAG, "⚠️ [$changeType] emp_id and company_code both empty — user not logged in — skipping API post")
            return
        }

        // NEW_DATE & NEW_TIME: Capture the newly set date and time (what user changed to)
        // After the device time has been changed, get the current system time which now reflects
        // the user's newly set date and time
        val changedNow = Date()
        val newDate    = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(changedNow)
        val newTime    = SimpleDateFormat("HH:mm:ss",   Locale.getDefault()).format(changedNow)

        android.util.Log.d(TAG, "🗓️ [$changeType] detected_at='$detectedAt' (actual detection timestamp)")
        android.util.Log.d(TAG, "🗓️ [$changeType] new_date='$newDate' (newly set date)")
        android.util.Log.d(TAG, "🗓️ [$changeType] new_time='$newTime' (newly set time)")

        // Battery level
        val battery = try {
            val bm    = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).coerceIn(0, 100)
            android.util.Log.d(TAG, "🔋 [$changeType] battery_percent=$level%")
            level
        } catch (e: Exception) {
            android.util.Log.w(TAG, "⚠️ [$changeType] Could not read battery level: ${e.message}")
            -1
        }

        val deviceModel    = Build.MODEL            ?: "unknown"
        val androidVersion = Build.VERSION.RELEASE  ?: "unknown"
        android.util.Log.d(TAG, "📲 [$changeType] device_model='$deviceModel'  android_version='$androidVersion'  app_version='$APP_VERSION'")

        val payload = JSONObject().apply {
            put("emp_id",          empId)
            put("emp_name",        empName)
            put("company_code",    companyCode)
            put("device_id",       deviceId)
            put("dep_id",          depId)
            put("change_type",     changeType)
            put("detected_at",     detectedAt)      // Actual timestamp when change was detected
            put("new_date",        newDate)         // Newly set date after change
            put("new_time",        newTime)         // Newly set time after change
            put("battery_percent", battery)
            put("device_model",    deviceModel)
            put("android_version", androidVersion)
            put("app_version",     APP_VERSION)
        }.toString()

        android.util.Log.d(TAG, "📦 [$changeType] Payload built → $payload")
        android.util.Log.d(TAG, "🌐 [$changeType] Launching background thread → POST $API_URL")

        Thread {
            android.util.Log.d(TAG, "🧵 [$changeType] Background thread started")
            postToApi(payload, changeType)
        }.start()
    }

    // ── Resolve emp_name from cached employee JSON ─────────────────────────
    // Flutter writes the full employee list as:
    //   prefs.setString('cached_employees_$companyCode', jsonEncode(items))
    //   → stored in Android SharedPreferences as 'flutter.cached_employees_{companyCode}'
    //
    // Each item in the JSON array contains at least emp_id and emp_name fields.
    // We find the matching employee and return their name.
    private fun resolveEmpNameFromCache(
        prefs: android.content.SharedPreferences,
        empId: String,
        companyCode: String,
        changeType: String
    ): String {
        val cacheKey = "flutter.cached_employees_$companyCode"
        android.util.Log.d(TAG, "🔍 [$changeType] Resolving emp_name from cache key='$cacheKey'")

        val raw = (prefs.all as Map<String, *>)[cacheKey]?.toString()?.trim() ?: run {
            android.util.Log.w(TAG, "⚠️ [$changeType] Cache key '$cacheKey' not found in prefs")
            return ""
        }

        if (raw.isEmpty() || raw == "null") {
            android.util.Log.w(TAG, "⚠️ [$changeType] Cache key '$cacheKey' is empty")
            return ""
        }

        return try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue

                // emp_id may be stored as int or string in the JSON
                val jsonEmpId = (obj.opt("emp_id") ?: obj.opt("EMP_ID"))?.toString()?.trim() ?: continue

                if (jsonEmpId == empId) {
                    val name = (obj.opt("emp_name") ?: obj.opt("EMP_NAME"))?.toString()?.trim() ?: ""
                    if (name.isNotEmpty() && name != "null") {
                        android.util.Log.d(TAG, "✅ [$changeType] emp_name resolved from cache → '$name'")
                        return name
                    }
                }
            }
            android.util.Log.w(TAG, "⚠️ [$changeType] emp_id '$empId' not found in cached_employees JSON (${arr.length()} entries)")
            ""
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] Failed to parse cached_employees JSON: ${e.message}")
            ""
        }
    }

    // ── HTTP POST helper ───────────────────────────────────────────────────
    private fun postToApi(jsonPayload: String, changeType: String) {
        try {
            android.util.Log.d(TAG, "📡 [$changeType] Opening connection → $API_URL")

            val conn = (URL(API_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
                doOutput        = true
                connectTimeout  = 15_000
                readTimeout     = 15_000
            }

            android.util.Log.d(TAG, "📤 [$changeType] Writing payload to output stream...")
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(jsonPayload) }

            val responseCode = conn.responseCode
            val responseMsg  = try { conn.responseMessage } catch (_: Exception) { "" }
            conn.disconnect()

            android.util.Log.d(TAG, "📥 [$changeType] Response → HTTP $responseCode '$responseMsg'")

            if (responseCode in 200..299) {
                android.util.Log.d(TAG, "✅ [$changeType] API post success — HTTP $responseCode $responseMsg")
            } else {
                android.util.Log.w(TAG, "⚠️ [$changeType] API returned non-2xx → HTTP $responseCode $responseMsg")
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] Network error: ${e.message}")
        }
    }

    // ── SharedPreferences helper ───────────────────────────────────────────
    // Tries each key in order, returns first non-empty value found.
    private fun firstNonEmpty(
        prefs: android.content.SharedPreferences,
        keys: List<String>
    ): String {
        // Snapshot into Map<String, *> so [key] calls Map.get() — never getString().
        // Indexing prefs.all[key] directly on a SharedPreferences reference can
        // resolve to the typed getString() getter and throw ClassCastException
        // when the stored value is a Long or Int (e.g. Flutter timestamps/flags).
        val map: Map<String, *> = prefs.all
        for (key in keys) {
            val raw = map[key]?.toString()?.trim() ?: continue
            if (raw.isNotEmpty() && raw != "null") {
                android.util.Log.d(TAG, "🔑 Key found: '$key' = '$raw'")
                return raw
            }
        }
        android.util.Log.w(TAG, "⚠️ No value found for keys: $keys")
        return ""
    }
}