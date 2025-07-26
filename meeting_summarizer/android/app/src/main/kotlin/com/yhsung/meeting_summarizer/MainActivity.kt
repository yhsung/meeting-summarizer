package com.yhsung.meeting_summarizer

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.yhsung.meeting_summarizer.platform.AndroidPlatformHandler

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yhsung.meeting_summarizer/android_platform"
    private lateinit var platformHandler: AndroidPlatformHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize platform handler
        platformHandler = AndroidPlatformHandler(this, flutterEngine.dartExecutor.binaryMessenger)
        
        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            platformHandler.handleMethodCall(call, result)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle intent from widgets, shortcuts, or Assistant
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent) {
        when (intent.action) {
            "com.yhsung.meeting_summarizer.START_RECORDING" -> {
                if (::platformHandler.isInitialized) {
                    platformHandler.handleAssistantAction("start_recording", null)
                }
            }
            "com.yhsung.meeting_summarizer.STOP_RECORDING" -> {
                if (::platformHandler.isInitialized) {
                    platformHandler.handleAssistantAction("stop_recording", null)
                }
            }
            Intent.ACTION_VIEW -> {
                // Handle deep links from widgets or Assistant
                intent.data?.let { uri ->
                    if (::platformHandler.isInitialized) {
                        platformHandler.handleDeepLink(uri)
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        if (::platformHandler.isInitialized) {
            platformHandler.dispose()
        }
        super.onDestroy()
    }
}
