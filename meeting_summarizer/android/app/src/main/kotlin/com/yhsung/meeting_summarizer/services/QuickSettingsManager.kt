package com.yhsung.meeting_summarizer.services

import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Manages Quick Settings tile functionality
 */
class QuickSettingsManager(private val context: Context) {
    companion object {
        private const val TAG = "QuickSettingsManager"
    }

    private var isEnabled = false

    fun setupTile(): Boolean {
        return try {
            // Check if Quick Settings tile is available
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                // Request tile to be added to Quick Settings
                // Note: User must manually add the tile through device settings
                isEnabled = true
                Log.d(TAG, "Quick Settings tile setup completed")
                true
            } else {
                Log.w(TAG, "Quick Settings tiles not supported on this Android version")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup Quick Settings tile", e)
            false
        }
    }

    fun updateTile(isRecording: Boolean, status: String, subtitle: String) {
        if (!isEnabled) return

        try {
            // Send broadcast to update tile state
            val intent = Intent("com.yhsung.meeting_summarizer.UPDATE_TILE").apply {
                putExtra("isRecording", isRecording)
                putExtra("status", status)
                putExtra("subtitle", subtitle)
                setPackage(context.packageName)
            }
            
            context.sendBroadcast(intent)
            Log.d(TAG, "Quick Settings tile updated: $status")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update Quick Settings tile", e)
        }
    }

    fun handleTileClick() {
        try {
            Log.d(TAG, "Quick Settings tile clicked")
            
            // Send broadcast about tile click
            val intent = Intent("com.yhsung.meeting_summarizer.TILE_CLICK").apply {
                setPackage(context.packageName)
            }
            
            context.sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling tile click", e)
        }
    }

    fun isEnabled(): Boolean = isEnabled

    fun dispose() {
        try {
            isEnabled = false
            Log.d(TAG, "Quick Settings manager disposed")
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing Quick Settings manager", e)
        }
    }
}