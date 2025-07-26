package com.yhsung.meeting_summarizer.services

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.yhsung.meeting_summarizer.MainActivity
import com.yhsung.meeting_summarizer.R

/**
 * Manages foreground service for background recording functionality
 */
class ForegroundServiceManager(private val context: Context) {
    companion object {
        private const val TAG = "ForegroundServiceManager"
        private const val NOTIFICATION_ID = 1001
    }

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var currentNotification: Notification? = null
    private var isServiceActive = false

    fun initialize(): Boolean {
        return try {
            Log.d(TAG, "Foreground service manager initialized")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize foreground service manager", e)
            false
        }
    }

    fun startService(
        title: String,
        content: String,
        channelId: String,
        channelName: String,
        importance: String,
        priority: String,
        showWhen: Boolean,
        ongoing: Boolean,
        autoCancel: Boolean
    ): Boolean {
        return try {
            val notification = createNotification(
                title, content, channelId, priority, showWhen, ongoing, autoCancel
            )
            
            currentNotification = notification
            notificationManager.notify(NOTIFICATION_ID, notification)
            isServiceActive = true
            
            Log.d(TAG, "Foreground service started: $title")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service", e)
            false
        }
    }

    fun updateService(
        title: String?,
        content: String?,
        progress: Int?,
        indeterminate: Boolean,
        actions: Map<String, String>,
        timestamp: Long
    ) {
        if (!isServiceActive) return

        try {
            val notification = createNotification(
                title ?: "Recording",
                content ?: "Recording in progress",
                "recording_service",
                "high",
                true,
                true,
                false,
                progress,
                indeterminate,
                actions
            )
            
            currentNotification = notification
            notificationManager.notify(NOTIFICATION_ID, notification)
            
            Log.d(TAG, "Foreground service updated")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update foreground service", e)
        }
    }

    fun stopService() {
        try {
            notificationManager.cancel(NOTIFICATION_ID)
            currentNotification = null
            isServiceActive = false
            
            Log.d(TAG, "Foreground service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop foreground service", e)
        }
    }

    private fun createNotification(
        title: String,
        content: String,
        channelId: String,
        priority: String,
        showWhen: Boolean,
        ongoing: Boolean,
        autoCancel: Boolean,
        progress: Int? = null,
        indeterminate: Boolean = false,
        actions: Map<String, String> = emptyMap()
    ): Notification {
        val notificationIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationPriority = when (priority) {
            "high" -> NotificationCompat.PRIORITY_HIGH
            "default" -> NotificationCompat.PRIORITY_DEFAULT
            "low" -> NotificationCompat.PRIORITY_LOW
            else -> NotificationCompat.PRIORITY_DEFAULT
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_media_play) // Use system icon for now
            .setContentIntent(pendingIntent)
            .setPriority(notificationPriority)
            .setShowWhen(showWhen)
            .setOngoing(ongoing)
            .setAutoCancel(autoCancel)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)

        // Add progress indicator if specified
        progress?.let {
            builder.setProgress(100, it, indeterminate)
        }

        // Add action buttons
        actions.forEach { (actionKey, actionLabel) ->
            val actionIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.yhsung.meeting_summarizer.${actionKey.uppercase()}"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            
            val actionPendingIntent = PendingIntent.getActivity(
                context, actionKey.hashCode(), actionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            builder.addAction(
                android.R.drawable.ic_media_pause, // Use system icon for now
                actionLabel,
                actionPendingIntent
            )
        }

        return builder.build()
    }

    fun isActive(): Boolean = isServiceActive

    fun dispose() {
        try {
            stopService()
            Log.d(TAG, "Foreground service manager disposed")
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing foreground service manager", e)
        }
    }
}