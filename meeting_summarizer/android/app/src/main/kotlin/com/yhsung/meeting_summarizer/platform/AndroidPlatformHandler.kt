package com.yhsung.meeting_summarizer.platform

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.yhsung.meeting_summarizer.services.ForegroundServiceManager
import com.yhsung.meeting_summarizer.services.QuickSettingsManager
import com.yhsung.meeting_summarizer.services.WorkProfileManager
import com.yhsung.meeting_summarizer.services.AssistantManager

/**
 * Central handler for all Android platform-specific functionality
 * Coordinates between Flutter and native Android services
 */
class AndroidPlatformHandler(
    private val activity: Activity,
    private val messenger: BinaryMessenger
) {
    companion object {
        private const val TAG = "AndroidPlatformHandler"
        private const val CHANNEL = "com.yhsung.meeting_summarizer/android_platform"
    }

    private val context: Context = activity.applicationContext
    private lateinit var methodChannel: MethodChannel
    
    // Service managers
    private lateinit var foregroundServiceManager: ForegroundServiceManager
    private lateinit var quickSettingsManager: QuickSettingsManager
    private lateinit var workProfileManager: WorkProfileManager
    private lateinit var assistantManager: AssistantManager
    
    private var isInitialized = false

    init {
        initializeServices()
        setupMethodChannel()
    }

    private fun initializeServices() {
        try {
            foregroundServiceManager = ForegroundServiceManager(context)
            quickSettingsManager = QuickSettingsManager(context)
            workProfileManager = WorkProfileManager(context)
            assistantManager = AssistantManager(context)
            
            // Create notification channel for foreground service
            createNotificationChannels()
            
            isInitialized = true
            Log.d(TAG, "Android platform services initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize platform services", e)
        }
    }

    private fun setupMethodChannel() {
        methodChannel = MethodChannel(messenger, CHANNEL)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Recording service channel
            val recordingChannel = NotificationChannel(
                "recording_service",
                "Recording Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for background recording service"
                enableVibration(false)
                setSound(null, null)
            }
            
            // Quick actions channel
            val quickActionsChannel = NotificationChannel(
                "quick_actions",
                "Quick Actions",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Quick action notifications and controls"
            }
            
            notificationManager.createNotificationChannel(recordingChannel)
            notificationManager.createNotificationChannel(quickActionsChannel)
        }
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    result.success(isInitialized)
                }
                
                "setupQuickSettingsTile" -> {
                    val success = quickSettingsManager.setupTile()
                    result.success(success)
                }
                
                "updateQuickSettingsTile" -> {
                    val isRecording = call.argument<Boolean>("isRecording") ?: false
                    val status = call.argument<String>("status") ?: ""
                    val subtitle = call.argument<String>("subtitle") ?: ""
                    
                    quickSettingsManager.updateTile(isRecording, status, subtitle)
                    result.success(true)
                }
                
                "setupGoogleAssistant" -> {
                    val success = assistantManager.setupAssistant()
                    result.success(success)
                }
                
                "registerAssistantAction" -> {
                    val action = call.argument<String>("action") ?: ""
                    val phrases = call.argument<List<String>>("phrases") ?: emptyList()
                    val description = call.argument<String>("description") ?: ""
                    
                    assistantManager.registerAction(action, phrases, description)
                    result.success(true)
                }
                
                "speakAssistantFeedback" -> {
                    val text = call.argument<String>("text") ?: ""
                    assistantManager.speakFeedback(text)
                    result.success(true)
                }
                
                "updateAssistantResult" -> {
                    val command = call.argument<String>("command") ?: ""
                    val success = call.argument<Boolean>("success") ?: false
                    val error = call.argument<String>("error")
                    val timestamp = call.argument<String>("timestamp") ?: ""
                    
                    assistantManager.updateResult(command, success, error, timestamp)
                    result.success(true)
                }
                
                "checkWorkProfileSupport" -> {
                    val workProfileInfo = workProfileManager.checkSupport()
                    result.success(workProfileInfo)
                }
                
                "configureWorkProfileSecurity" -> {
                    val config = call.arguments as? Map<String, Any> ?: emptyMap()
                    workProfileManager.configureSecurity(config)
                    result.success(true)
                }
                
                "setupWorkProfileCompliance" -> {
                    val config = call.arguments as? Map<String, Any> ?: emptyMap()
                    workProfileManager.setupCompliance(config)
                    result.success(true)
                }
                
                "applyWorkProfileRestrictions" -> {
                    val restrictions = call.arguments as? Map<String, Any> ?: emptyMap()
                    workProfileManager.applyRestrictions(restrictions)
                    result.success(true)
                }
                
                "isWorkProfile" -> {
                    val isWorkProfile = workProfileManager.isWorkProfile()
                    result.success(isWorkProfile)
                }
                
                "initializeForegroundService" -> {
                    val success = foregroundServiceManager.initialize()
                    result.success(success)
                }
                
                "startForegroundService" -> {
                    val title = call.argument<String>("title") ?: "Recording"
                    val content = call.argument<String>("content") ?: "Recording in progress"
                    val channelId = call.argument<String>("channelId") ?: "recording_service"
                    val channelName = call.argument<String>("channelName") ?: "Recording Service"
                    val importance = call.argument<String>("importance") ?: "high"
                    val priority = call.argument<String>("priority") ?: "high"
                    val showWhen = call.argument<Boolean>("showWhen") ?: true
                    val ongoing = call.argument<Boolean>("ongoing") ?: true
                    val autoCancel = call.argument<Boolean>("autoCancel") ?: false
                    
                    val success = foregroundServiceManager.startService(
                        title, content, channelId, channelName, importance, priority, showWhen, ongoing, autoCancel
                    )
                    result.success(success)
                }
                
                "updateForegroundService" -> {
                    val title = call.argument<String?>("title")
                    val content = call.argument<String?>("content")
                    val progress = call.argument<Int?>("progress")
                    val indeterminate = call.argument<Boolean>("indeterminate") ?: false
                    val actions = call.argument<Map<String, String>>("actions") ?: emptyMap()
                    val timestamp = call.argument<Long>("timestamp") ?: System.currentTimeMillis()
                    
                    foregroundServiceManager.updateService(title, content, progress, indeterminate, actions, timestamp)
                    result.success(true)
                }
                
                "stopForegroundService" -> {
                    foregroundServiceManager.stopService()
                    result.success(true)
                }
                
                else -> {
                    Log.w(TAG, "Unknown method call: ${call.method}")
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling method call: ${call.method}", e)
            result.error("PLATFORM_ERROR", "Failed to handle ${call.method}: ${e.message}", null)
        }
    }

    fun handleAssistantAction(action: String, parameters: Map<String, Any>?) {
        try {
            Log.d(TAG, "Handling Assistant action: $action")
            
            // Notify Flutter about the Assistant command
            methodChannel.invokeMethod("onAssistantCommand", mapOf(
                "command" to action,
                "parameters" to parameters
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling Assistant action: $action", e)
        }
    }

    fun handleQuickSettingsClick() {
        try {
            Log.d(TAG, "Quick Settings tile clicked")
            
            // Notify Flutter about the tile click
            methodChannel.invokeMethod("onQuickSettingsTileClick", null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling Quick Settings click", e)
        }
    }

    fun handleWidgetAction(action: String, parameters: Map<String, Any>?) {
        try {
            Log.d(TAG, "Handling widget action: $action")
            
            // Notify Flutter about the widget action
            methodChannel.invokeMethod("onWidgetAction", mapOf(
                "action" to action,
                "parameters" to parameters
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling widget action: $action", e)
        }
    }

    fun handleDeepLink(uri: Uri) {
        try {
            Log.d(TAG, "Handling deep link: $uri")
            
            val action = uri.getQueryParameter("type")
            val source = uri.getQueryParameter("source")
            
            if (action != null) {
                val parameters = mutableMapOf<String, Any>("source" to (source ?: "unknown"))
                
                // Add all query parameters
                for (paramName in uri.queryParameterNames) {
                    if (paramName != "type" && paramName != "source") {
                        uri.getQueryParameter(paramName)?.let { value ->
                            parameters[paramName] = value
                        }
                    }
                }
                
                handleWidgetAction(action, parameters)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling deep link: $uri", e)
        }
    }

    fun notifyForegroundServiceStateChanged(isActive: Boolean) {
        try {
            methodChannel.invokeMethod("onForegroundServiceStateChanged", mapOf(
                "isActive" to isActive
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error notifying foreground service state change", e)
        }
    }

    fun dispose() {
        try {
            if (isInitialized) {
                foregroundServiceManager.dispose()
                quickSettingsManager.dispose()
                workProfileManager.dispose()
                assistantManager.dispose()
                
                isInitialized = false
                Log.d(TAG, "Android platform handler disposed")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing platform handler", e)
        }
    }
}