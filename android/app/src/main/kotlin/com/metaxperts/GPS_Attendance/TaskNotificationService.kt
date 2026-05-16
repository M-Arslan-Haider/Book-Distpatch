package com.metaxperts.GPS_Workforce_Monitor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat

object TaskNotificationService {

    private const val CHANNEL_ID   = "task_assigned_channel"
    private const val CHANNEL_NAME = "Task Notifications"
    private const val CHANNEL_DESC = "Notifications for newly assigned tasks"

    private var notifCounter = 3000

    // ──────────────────────────────────────────────────────────────────────────
    //  Register channel — call once in MainActivity.onCreate
    // ──────────────────────────────────────────────────────────────────────────
    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description      = CHANNEL_DESC
                enableLights(true)
                lightColor       = Color.parseColor("#0EA5E9")   // sky blue LED
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 150, 300)
                setShowBadge(true)
            }
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    //  Show professional heads-up notification
    // ──────────────────────────────────────────────────────────────────────────
    fun showNewTaskNotification(
        context:    Context,
        taskTitle:  String,
        taskDesc:   String = "",
        assignedBy: String = ""
    ) {
        try {
            val openIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP }

            val pendingIntent = PendingIntent.getActivity(
                context,
                notifCounter,
                openIntent ?: Intent(),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // ── Expanded (BigText) body ───────────────────────────────────
            //
            //   🆕 New Task Assigned
            //   ─────────────────────────────
            //   📋  <taskTitle>
            //
            //   <taskDesc>  (if present)
            //
            //   👤 Assigned by: <assignedBy>
            //
            val expandedBody = buildString {
                append("━━━━━━━━━━━━━━━━━━━━━━━━\n")
                append("📋  ${taskTitle.ifBlank { "New task" }}\n")
                if (taskDesc.isNotBlank()) {
                    append("\n${taskDesc}\n")
                }
                if (assignedBy.isNotBlank()) {
                    append("\n👤 Assigned by:  $assignedBy")
                }
            }

            // ── Collapsed (one-line) ticker ───────────────────────────────
            val collapsedText = buildString {
                append(taskTitle.ifBlank { "New task assigned" })
                if (assignedBy.isNotBlank()) append("  •  by $assignedBy")
            }

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                // ── Title row ───────────────────────────────────────────
                .setContentTitle("🆕  New Task Assigned")
                // ── Collapsed body ──────────────────────────────────────
                .setContentText(collapsedText)
                // ── Expanded body ───────────────────────────────────────
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .setBigContentTitle("🆕  New Task Assigned")
                        .bigText(expandedBody)
                        .setSummaryText("GPS Workforce Monitor")
                )
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 300, 150, 300))
                .setLights(Color.parseColor("#0EA5E9"), 500, 500)
                .setColor(Color.parseColor("#0EA5E9"))          // accent tint on icon
                .setColorized(false)
                .build()

            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(notifCounter++, notification)

            android.util.Log.d("TaskNotification", "✅ Notification shown — $taskTitle")

        } catch (e: Exception) {
            android.util.Log.e("TaskNotification", "❌ Error: ${e.message}")
        }
    }
}