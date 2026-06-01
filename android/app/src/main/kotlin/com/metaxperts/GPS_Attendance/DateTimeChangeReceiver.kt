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
// ── OFFLINE QUEUE SUPPORT ─────────────────────────────────────────────────
//   • If device is OFFLINE when date/time changes, the payload is saved to
//     SharedPreferences ("DateTimeChangePending" / key "pending_queue").
//   • A WorkManager job (PendingSyncWorker — defined at bottom of this file)
//     is scheduled with NETWORK_CONNECTED constraint. It fires automatically
//     as soon as network is restored, even if app is fully killed.
//   • If the API post FAILS (server error / timeout), payload is also queued
//     and WorkManager retries with exponential back-off.
//   • On every date/time change, pending queue is pre-flushed as a safety net.
//
// DEPENDENCY (add to app/build.gradle if not already present):
//   implementation "androidx.work:work-runtime-ktx:2.9.0"
//
// MANIFEST REGISTRATION (unchanged — no extra actions needed):
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
//   detected_at     — Actual current timestamp when change was detected
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
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
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
    private val API_URL        = "http://oracle.metaxperts.net/ords/gps_workforce/datetimechange/post/"
    private val APP_VERSION    = "2.3"
    private val PREFS_NAME     = "FlutterSharedPreferences"
    private val TAG            = "DateTimeChangeReceiver"

    // ── Offline queue config ───────────────────────────────────────────────
    private val PENDING_PREFS  = "DateTimeChangePending"
    private val PENDING_KEY    = "pending_queue"
    private val SYNC_WORK_NAME = "datetime_pending_sync"

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
        val companyCode = firstNonEmpty(prefs, listOf(
            "flutter.cached_employees_company",
            "flutter.company_code",
            "company_code",
            "flutter.cached_company_code"
        ))
        android.util.Log.d(TAG, "🏢 [$changeType] company_code='$companyCode'")

        // ── emp_name ──────────────────────────────────────────────────────
        var empName = firstNonEmpty(prefs, listOf(
            "flutter.emp_name",
            "emp_name"
        ))
        if (empName.isEmpty() && empId.isNotEmpty() && companyCode.isNotEmpty()) {
            empName = resolveEmpNameFromCache(prefs, empId, companyCode, changeType)
        }
        android.util.Log.d(TAG, "👤 [$changeType] emp_name='$empName'")

        // ── device_id ─────────────────────────────────────────────────────
        var deviceId = firstNonEmpty(prefs, listOf(
            "flutter.user_name",
            "user_name"
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
        val changedNow = Date()
        val newDate    = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(changedNow)
        val newTime    = SimpleDateFormat("HH:mm:ss",   Locale.getDefault()).format(changedNow)

        android.util.Log.d(TAG, "🗓️ [$changeType] detected_at='$detectedAt'")
        android.util.Log.d(TAG, "🗓️ [$changeType] new_date='$newDate'")
        android.util.Log.d(TAG, "🗓️ [$changeType] new_time='$newTime'")

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
            put("detected_at",     detectedAt)
            put("new_date",        newDate)
            put("new_time",        newTime)
            put("battery_percent", battery)
            put("device_model",    deviceModel)
            put("android_version", androidVersion)
            put("app_version",     APP_VERSION)
        }.toString()

        android.util.Log.d(TAG, "📦 [$changeType] Payload built → $payload")

        Thread {
            android.util.Log.d(TAG, "🧵 [$changeType] Background thread started")

            // Always pre-flush any older pending payloads first (safety net)
            flushPendingPayloads(context, changeType)

            if (isNetworkAvailable(context)) {
                android.util.Log.d(TAG, "🌐 [$changeType] Online — posting to API")
                val success = postToApi(payload, changeType)
                if (!success) {
                    android.util.Log.w(TAG, "⚠️ [$changeType] Post failed — saving to offline queue, WorkManager will retry")
                    savePendingPayload(context, payload, changeType)
                }
            } else {
                android.util.Log.w(TAG, "📴 [$changeType] Offline — saving to queue, WorkManager will post when online")
                savePendingPayload(context, payload, changeType)
            }
        }.start()
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Offline Queue Helpers
    // ══════════════════════════════════════════════════════════════════════════

    private fun savePendingPayload(context: Context, jsonPayload: String, changeType: String) {
        try {
            val pendingPrefs = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
            val existing     = pendingPrefs.getString(PENDING_KEY, "[]") ?: "[]"
            val arr          = try { JSONArray(existing) } catch (_: Exception) { JSONArray() }
            arr.put(JSONObject(jsonPayload))
            pendingPrefs.edit().putString(PENDING_KEY, arr.toString()).apply()
            android.util.Log.d(TAG, "💾 [$changeType] Saved to offline queue — total pending: ${arr.length()}")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] Failed to save pending payload: ${e.message}")
        }
        // Schedule WorkManager — runs when NETWORK_CONNECTED, survives app kill
        scheduleWorkManagerSync(context, changeType)
    }

    private fun scheduleWorkManagerSync(context: Context, changeType: String) {
        try {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val syncWork = OneTimeWorkRequestBuilder<PendingSyncWorker>()
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context.applicationContext)
                .enqueueUniqueWork(SYNC_WORK_NAME, ExistingWorkPolicy.KEEP, syncWork)

            android.util.Log.d(TAG, "📅 [$changeType] WorkManager job scheduled — will run when online")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] Failed to schedule WorkManager job: ${e.message}")
        }
    }

    private fun flushPendingPayloads(context: Context, changeType: String) {
        if (!isNetworkAvailable(context)) {
            android.util.Log.d(TAG, "📴 [$changeType] Offline — skipping pre-flush")
            return
        }
        val pendingPrefs = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
        val raw          = pendingPrefs.getString(PENDING_KEY, "[]") ?: "[]"
        val arr          = try { JSONArray(raw) } catch (e: Exception) { return }

        if (arr.length() == 0) return

        android.util.Log.d(TAG, "📤 [$changeType] Pre-flushing ${arr.length()} pending payload(s)")
        val remaining = JSONArray()
        for (i in 0 until arr.length()) {
            val item = arr.optJSONObject(i) ?: continue
            val ct   = item.optString("change_type", "PENDING")
            if (!postToApi(item.toString(), "$ct[retry]")) remaining.put(item)
        }
        pendingPrefs.edit().putString(PENDING_KEY, remaining.toString()).apply()
        android.util.Log.d(TAG, "✅ [$changeType] Pre-flush done — sent=${arr.length() - remaining.length()}  still_pending=${remaining.length()}")
    }

    private fun isNetworkAvailable(context: Context): Boolean {
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = cm.activeNetwork ?: return false
                val caps    = cm.getNetworkCapabilities(network) ?: return false
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                        caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            } else {
                @Suppress("DEPRECATION")
                cm.activeNetworkInfo?.isConnected == true
            }
        } catch (e: Exception) {
            android.util.Log.w(TAG, "⚠️ isNetworkAvailable check failed: ${e.message}")
            false
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Existing Helpers (unchanged)
    // ══════════════════════════════════════════════════════════════════════════

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

    private fun postToApi(jsonPayload: String, changeType: String): Boolean {
        return try {
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
                true
            } else {
                android.util.Log.w(TAG, "⚠️ [$changeType] API returned non-2xx → HTTP $responseCode $responseMsg")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] Network error: ${e.message}")
            false
        }
    }

    private fun firstNonEmpty(
        prefs: android.content.SharedPreferences,
        keys: List<String>
    ): String {
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

// ══════════════════════════════════════════════════════════════════════════════
// PendingSyncWorker
//
// WorkManager Worker — defined in the same file, no separate file needed.
// Runs automatically when network is restored (even if app is fully killed).
// Flushes all pending date/time-change payloads from the offline queue.
// ══════════════════════════════════════════════════════════════════════════════
class PendingSyncWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    private val API_URL       = "http://oracle.metaxperts.net/ords/gps_workforce/datetimechange/post/"
    private val PENDING_PREFS = "DateTimeChangePending"
    private val PENDING_KEY   = "pending_queue"
    private val TAG           = "PendingSyncWorker"

    override fun doWork(): Result {
        return try {
            android.util.Log.d(TAG, "🔄 WorkManager started — flushing pending queue")

            val prefs = applicationContext.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
            val raw   = prefs.getString(PENDING_KEY, "[]") ?: "[]"
            val arr   = try { JSONArray(raw) } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Cannot parse queue: ${e.message}")
                return Result.failure()
            }

            if (arr.length() == 0) {
                android.util.Log.d(TAG, "✅ Queue empty — nothing to do")
                return Result.success()
            }

            android.util.Log.d(TAG, "📤 Sending ${arr.length()} pending payload(s)")
            val remaining = JSONArray()

            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i) ?: continue
                val ct   = item.optString("change_type", "PENDING")
                if (postToApi(item.toString(), ct)) {
                    android.util.Log.d(TAG, "✅ Item $i sent — change_type='$ct'")
                } else {
                    android.util.Log.w(TAG, "⚠️ Item $i failed — keeping for retry")
                    remaining.put(item)
                }
            }

            prefs.edit().putString(PENDING_KEY, remaining.toString()).apply()
            val sent = arr.length() - remaining.length()
            android.util.Log.d(TAG, "✅ WorkManager done — sent=$sent  still_pending=${remaining.length()}")

            if (remaining.length() == 0) Result.success() else Result.retry()

        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ WorkManager exception: ${e.message}")
            Result.retry()
        }
    }

    private fun postToApi(jsonPayload: String, changeType: String): Boolean {
        return try {
            val conn = (URL(API_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
                doOutput       = true
                connectTimeout = 15_000
                readTimeout    = 15_000
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(jsonPayload) }
            val code = conn.responseCode
            conn.disconnect()
            android.util.Log.d(TAG, "📥 [$changeType] HTTP $code")
            code in 200..299
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ [$changeType] ${e.message}")
            false
        }
    }
}