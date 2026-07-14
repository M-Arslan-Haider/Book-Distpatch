package com.metaxperts.bookdispatch

// ════════════════════════════════════════════════════════════════════════════
//  NotificationApiLogger.kt
//
//  Har notification fire hone ke baad is helper ko call karo.
//  POST: http://oracle.metaxperts.net/ords/gps_workforce/notification/post/
//  Body: { emp_id, emp_name, company_code, notification_title, notification_time }
//
//  ✅ Online        → turant POST
//  ✅ Offline       → file mein save, agli notification par flush
//  ✅ App killed    → applicationContext + non-daemon thread
//  ✅ Oracle fix    → notification_time = "yyyy-MM-dd HH:mm:ss" (no T)
//                     ORA-01843 "not a valid month" error FIXED
// ════════════════════════════════════════════════════════════════════════════

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NotificationApiLogger {

    private const val TAG          = "NotifApiLogger"
    private const val POST_URL     = "http://oracle.metaxperts.net/ords/gps_workforce/notification/post/"
    private const val OFFLINE_FILE = "notification_log_offline.json"
    private const val PREFS_NAME   = "FlutterSharedPreferences"

    // Oracle TIMESTAMP format — space not T (ORA-01843 fix)
    private val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())

    fun log(context: Context, notificationTitle: String) {
        val notificationTime = sdf.format(Date())

        Log.d(TAG, "")
        Log.d(TAG, "==================================================")
        Log.d(TAG, "[NOTIF LOG] log() called")
        Log.d(TAG, "   title = \"$notificationTitle\"")
        Log.d(TAG, "   time  = $notificationTime")

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val empId = readPref(prefs, listOf(
            "flutter.emp_id", "flutter.user_name", "flutter.user_id",
            "emp_id", "user_name", "user_id"
        ))
        val empName     = readPref(prefs, listOf("flutter.emp_name",     "emp_name"))
        val companyCode = readPref(prefs, listOf("flutter.company_code", "company_code"))

        Log.d(TAG, "   [IDENTITY] empId       = \"$empId\"")
        Log.d(TAG, "   [IDENTITY] empName     = \"$empName\"")
        Log.d(TAG, "   [IDENTITY] companyCode = \"$companyCode\"")

        val record = JSONObject().apply {
            put("emp_id",             empId)
            put("emp_name",           empName)
            put("company_code",       companyCode)
            put("notification_title", notificationTitle)
            put("notification_time",  notificationTime)
        }

        Log.d(TAG, "   [PAYLOAD] $record")
        Log.d(TAG, "==================================================")
        Log.d(TAG, "")

        val appCtx = context.applicationContext
        Thread {
            Log.d(TAG, "[THREAD] Background thread started")
            flushOfflineQueue(appCtx)
            postRecord(appCtx, record)
        }.also { it.isDaemon = false }.start()
    }

    private fun postRecord(context: Context, record: JSONObject) {
        val safeRecord = fixTimestamp(record)
        try {
            val body = safeRecord.toString()
            Log.d(TAG, "")
            Log.d(TAG, "[POST] URL  = $POST_URL")
            Log.d(TAG, "[POST] Body = $body")

            val conn = (URL(POST_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept",       "application/json")
                doOutput       = true
                connectTimeout = 15_000
                readTimeout    = 15_000
            }
            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            val code = conn.responseCode
            val msg  = try { conn.responseMessage } catch (_: Exception) { "" }
            val responseBody = try {
                val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                stream?.bufferedReader()?.readText()?.trim() ?: ""
            } catch (_: Exception) { "" }
            conn.disconnect()

            Log.d(TAG, "[POST] Response code = $code  msg = $msg")
            if (responseBody.isNotEmpty())
                Log.d(TAG, "[POST] Response body = $responseBody")

            if (code in 200..299) {
                Log.d(TAG, "SUCCESS [POST] notification logged to API")
            } else {
                Log.w(TAG, "FAILED  [POST] HTTP $code -> saving to offline queue")
                saveOffline(context, safeRecord)
            }
        } catch (e: Exception) {
            Log.e(TAG, "EXCEPTION [POST] ${e.javaClass.simpleName}: ${e.message} -> saving offline")
            saveOffline(context, safeRecord)
        }
    }

    private fun saveOffline(context: Context, record: JSONObject) {
        try {
            val file  = File(context.filesDir, OFFLINE_FILE)
            val array = if (file.exists()) {
                try { JSONArray(file.readText()) } catch (_: Exception) { JSONArray() }
            } else JSONArray()
            array.put(record)
            file.writeText(array.toString())
            Log.d(TAG, "[OFFLINE] Saved — total queued: ${array.length()}")
        } catch (e: Exception) {
            Log.e(TAG, "[OFFLINE] saveOffline error: ${e.message}")
        }
    }

    private fun flushOfflineQueue(context: Context) {
        try {
            val file = File(context.filesDir, OFFLINE_FILE)
            if (!file.exists()) { Log.d(TAG, "[FLUSH] No offline file"); return }
            val content = file.readText().trim()
            if (content.isEmpty()) { file.delete(); return }
            val array = JSONArray(content)
            if (array.length() == 0) { file.delete(); return }

            Log.d(TAG, "[FLUSH] Found ${array.length()} offline records — flushing...")
            val failed = JSONArray()

            for (i in 0 until array.length()) {
                val rec = fixTimestamp(array.getJSONObject(i))  // fix old T-format records
                var success = false
                Log.d(TAG, "[FLUSH] Posting record $i: $rec")
                try {
                    val conn = (URL(POST_URL).openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("Accept",       "application/json")
                        doOutput       = true
                        connectTimeout = 15_000
                        readTimeout    = 15_000
                    }
                    OutputStreamWriter(conn.outputStream).use { it.write(rec.toString()) }
                    val code = conn.responseCode
                    conn.disconnect()
                    Log.d(TAG, "[FLUSH] Record $i -> HTTP $code")
                    if (code in 200..299) success = true
                } catch (e: Exception) {
                    Log.e(TAG, "[FLUSH] Record $i exception: ${e.message}")
                }
                if (!success) failed.put(rec)
            }

            if (failed.length() == 0) {
                file.delete()
                Log.d(TAG, "SUCCESS [FLUSH] All offline records posted")
            } else {
                file.writeText(failed.toString())
                Log.w(TAG, "[FLUSH] ${failed.length()} records still offline — will retry next time")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[FLUSH] error: ${e.message}")
        }
    }

    // Oracle fix: "2026-05-07T14:33:51" -> "2026-05-07 14:33:51"
    private fun fixTimestamp(record: JSONObject): JSONObject {
        return try {
            val raw = record.optString("notification_time", "")
            if (raw.contains("T")) {
                val fixed = raw.replace("T", " ")
                Log.d(TAG, "[TIMESTAMP FIX] $raw -> $fixed")
                JSONObject(record.toString()).apply { put("notification_time", fixed) }
            } else record
        } catch (_: Exception) { record }
    }

    private fun readPref(prefs: android.content.SharedPreferences, keys: List<String>): String {
        for (key in keys) {
            val raw = try { prefs.all[key]?.toString()?.trim() } catch (_: Exception) { null }
            if (!raw.isNullOrEmpty() && raw != "null") return raw
        }
        return ""
    }
}