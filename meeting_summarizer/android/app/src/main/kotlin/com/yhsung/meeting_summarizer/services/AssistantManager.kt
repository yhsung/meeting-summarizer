package com.yhsung.meeting_summarizer.services

import android.content.Context
import android.content.Intent
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.*

/**
 * Manages Google Assistant integration and voice commands
 */
class AssistantManager(private val context: Context) : TextToSpeech.OnInitListener {
    companion object {
        private const val TAG = "AssistantManager"
    }

    private var textToSpeech: TextToSpeech? = null
    private var isAssistantEnabled = false
    private var isTtsInitialized = false
    private val registeredActions = mutableMapOf<String, AssistantAction>()

    data class AssistantAction(
        val action: String,
        val phrases: List<String>,
        val description: String
    )

    fun setupAssistant(): Boolean {
        return try {
            // Initialize Text-to-Speech for voice feedback
            textToSpeech = TextToSpeech(context, this)
            
            // Check if Google Assistant is available
            isAssistantEnabled = checkAssistantAvailability()
            
            if (isAssistantEnabled) {
                setupAppActions()
                Log.d(TAG, "Google Assistant integration setup completed")
            } else {
                Log.w(TAG, "Google Assistant not available on this device")
            }
            
            isAssistantEnabled
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup Google Assistant", e)
            false
        }
    }

    private fun checkAssistantAvailability(): Boolean {
        return try {
            // Check if device has Google Assistant capability
            val intent = Intent("android.intent.action.ASSIST")
            val assistApps = context.packageManager.queryIntentActivities(intent, 0)
            
            assistApps.any { it.activityInfo.packageName.contains("google") }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Assistant availability", e)
            false
        }
    }

    private fun setupAppActions() {
        try {
            // Set up App Actions for Google Assistant
            // These would be configured through the Google Developer Console
            // and the actions.xml file in the app
            
            Log.d(TAG, "App Actions setup completed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup App Actions", e)
        }
    }

    fun registerAction(action: String, phrases: List<String>, description: String) {
        try {
            val assistantAction = AssistantAction(action, phrases, description)
            registeredActions[action] = assistantAction
            
            // Create intent filter for the action
            createActionIntent(action, phrases)
            
            Log.d(TAG, "Assistant action registered: $action")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register Assistant action: $action", e)
        }
    }

    private fun createActionIntent(action: String, phrases: List<String>) {
        try {
            // Create intent that can be triggered by Assistant
            val intent = Intent("com.yhsung.meeting_summarizer.${action.uppercase()}").apply {
                setPackage(context.packageName)
                putExtra("phrases", phrases.toTypedArray())
                putExtra("timestamp", System.currentTimeMillis())
            }
            
            // Register the intent with the system
            context.sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create action intent for: $action", e)
        }
    }

    fun speakFeedback(text: String) {
        try {
            if (isTtsInitialized && textToSpeech != null) {
                textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "feedback")
                Log.d(TAG, "Speaking feedback: $text")
            } else {
                Log.w(TAG, "TTS not initialized, cannot speak feedback")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to speak feedback: $text", e)
        }
    }

    fun updateResult(command: String, success: Boolean, error: String?, timestamp: String) {
        try {
            // Log the result for debugging and analytics
            val resultData = mapOf(
                "command" to command,
                "success" to success,
                "error" to error,
                "timestamp" to timestamp,
                "sessionId" to generateSessionId()
            )
            
            Log.d(TAG, "Assistant command result: $resultData")
            
            // Store result for future analysis
            storeCommandResult(resultData)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update Assistant result", e)
        }
    }

    private fun generateSessionId(): String {
        return UUID.randomUUID().toString().substring(0, 8)
    }

    private fun storeCommandResult(resultData: Map<String, Any?>) {
        try {
            // Store command results for analytics and debugging
            // This could be stored in SharedPreferences, database, or sent to analytics
            val prefs = context.getSharedPreferences("assistant_results", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            
            val key = "result_${System.currentTimeMillis()}"
            val value = resultData.toString()
            
            editor.putString(key, value)
            editor.apply()
            
            // Clean up old results (keep only last 50)
            cleanupOldResults(prefs)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to store command result", e)
        }
    }

    private fun cleanupOldResults(prefs: android.content.SharedPreferences) {
        try {
            val allResults = prefs.all.keys.filter { it.startsWith("result_") }
            if (allResults.size > 50) {
                val sortedKeys = allResults.sorted()
                val keysToRemove = sortedKeys.take(allResults.size - 50)
                
                val editor = prefs.edit()
                keysToRemove.forEach { key ->
                    editor.remove(key)
                }
                editor.apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cleanup old results", e)
        }
    }

    fun handleVoiceCommand(command: String, parameters: Map<String, Any>?) {
        try {
            Log.d(TAG, "Handling voice command: $command")
            
            // Find matching registered action
            val action = registeredActions.values.find { assistantAction ->
                assistantAction.phrases.any { phrase ->
                    command.lowercase().contains(phrase.lowercase())
                }
            }
            
            if (action != null) {
                // Execute the action
                executeAction(action.action, parameters)
                
                // Provide voice feedback
                val feedback = when (action.action) {
                    "start_recording" -> "Starting meeting recording"
                    "stop_recording" -> "Stopping recording"
                    "transcribe_recording" -> "Starting transcription"
                    "show_recent_recordings" -> "Showing recent recordings"
                    else -> "Processing your request"
                }
                
                speakFeedback(feedback)
            } else {
                Log.w(TAG, "No matching action found for command: $command")
                speakFeedback("Sorry, I didn't understand that command")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling voice command: $command", e)
            speakFeedback("Sorry, there was an error processing your request")
        }
    }

    private fun executeAction(action: String, parameters: Map<String, Any>?) {
        try {
            // Send broadcast to notify the app about the action
            val intent = Intent("com.yhsung.meeting_summarizer.ASSISTANT_ACTION").apply {
                putExtra("action", action)
                putExtra("parameters", parameters?.let { HashMap(it) })
                putExtra("timestamp", System.currentTimeMillis())
                setPackage(context.packageName)
            }
            
            context.sendBroadcast(intent)
            Log.d(TAG, "Assistant action executed: $action")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to execute action: $action", e)
        }
    }

    fun getRegisteredActions(): List<AssistantAction> {
        return registeredActions.values.toList()
    }

    fun isEnabled(): Boolean = isAssistantEnabled

    fun isTtsReady(): Boolean = isTtsInitialized

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            textToSpeech?.let { tts ->
                val result = tts.setLanguage(Locale.getDefault())
                
                if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                    Log.w(TAG, "TTS language not supported, using default")
                    tts.setLanguage(Locale.US)
                }
                
                isTtsInitialized = true
                Log.d(TAG, "Text-to-Speech initialized successfully")
            }
        } else {
            Log.e(TAG, "Text-to-Speech initialization failed")
            isTtsInitialized = false
        }
    }

    fun dispose() {
        try {
            textToSpeech?.let { tts ->
                tts.stop()
                tts.shutdown()
            }
            textToSpeech = null
            isTtsInitialized = false
            isAssistantEnabled = false
            registeredActions.clear()
            
            Log.d(TAG, "Assistant manager disposed")
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing Assistant manager", e)
        }
    }
}