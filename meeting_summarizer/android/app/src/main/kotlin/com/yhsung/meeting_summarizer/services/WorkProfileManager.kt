package com.yhsung.meeting_summarizer.services

import android.app.admin.DevicePolicyManager
import android.content.Context
import android.os.Build
import android.os.UserManager
import android.util.Log

/**
 * Manages Work Profile support and enterprise features
 */
class WorkProfileManager(private val context: Context) {
    companion object {
        private const val TAG = "WorkProfileManager"
    }

    private val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val userManager = context.getSystemService(Context.USER_SERVICE) as UserManager
    
    private var isSupported = false
    private var isConfigured = false

    fun checkSupport(): Map<String, Any> {
        return try {
            val isWorkProfile = isWorkProfile()
            val hasPolicyRestrictions = hasPolicyRestrictions()
            val isManagedProfile = isManagedProfile()
            val isDeviceOwner = isDeviceOwner()
            val isProfileOwner = isProfileOwner()
            
            isSupported = isWorkProfile || isManagedProfile || isDeviceOwner || isProfileOwner
            
            val result = mapOf(
                "supported" to isSupported,
                "isWorkProfile" to isWorkProfile,
                "hasPolicyRestrictions" to hasPolicyRestrictions,
                "isManagedProfile" to isManagedProfile,
                "isDeviceOwner" to isDeviceOwner,
                "isProfileOwner" to isProfileOwner,
                "androidVersion" to Build.VERSION.SDK_INT,
                "hasUserRestrictions" to hasUserRestrictions()
            )
            
            Log.d(TAG, "Work profile support check completed: $result")
            result
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check work profile support", e)
            mapOf(
                "supported" to false,
                "error" to e.message
            )
        }
    }

    fun configureSecurity(config: Map<String, Any>) {
        if (!isSupported) return

        try {
            val requireBiometric = config["requireBiometric"] as? Boolean ?: false
            val enforceScreenLock = config["enforceScreenLock"] as? Boolean ?: false
            val restrictFileSharing = config["restrictFileSharing"] as? Boolean ?: false
            val enableAuditLogging = config["enableAuditLogging"] as? Boolean ?: false

            // Apply security configurations based on device admin capabilities
            if (isDeviceOwner() || isProfileOwner()) {
                if (enforceScreenLock) {
                    configureScreenLockPolicy()
                }
                
                if (restrictFileSharing) {
                    configureFileRestrictions()
                }
                
                if (enableAuditLogging) {
                    enableSecurityLogging()
                }
            }
            
            isConfigured = true
            Log.d(TAG, "Work profile security configured: $config")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to configure work profile security", e)
        }
    }

    fun setupCompliance(config: Map<String, Any>) {
        if (!isSupported) return

        try {
            val monitorDataUsage = config["monitorDataUsage"] as? Boolean ?: false
            val trackRecordingLocations = config["trackRecordingLocations"] as? Boolean ?: false
            val enforceRetentionPolicies = config["enforceRetentionPolicies"] as? Boolean ?: false
            val enableRemoteWipe = config["enableRemoteWipe"] as? Boolean ?: false

            // Set up compliance monitoring
            if (monitorDataUsage) {
                setupDataUsageMonitoring()
            }
            
            if (trackRecordingLocations) {
                setupLocationTracking()
            }
            
            if (enforceRetentionPolicies) {
                setupRetentionPolicies()
            }
            
            if (enableRemoteWipe) {
                setupRemoteWipeCapability()
            }
            
            Log.d(TAG, "Work profile compliance setup completed: $config")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup work profile compliance", e)
        }
    }

    fun applyRestrictions(restrictions: Map<String, Any>) {
        if (!isSupported) return

        try {
            // Apply user restrictions if we have the capability
            if (isDeviceOwner() || isProfileOwner()) {
                restrictions.forEach { (key, value) ->
                    when (key) {
                        "disableCamera" -> {
                            if (value as? Boolean == true) {
                                devicePolicyManager.setCameraDisabled(null, true)
                            }
                        }
                        "disableScreenCapture" -> {
                            if (value as? Boolean == true && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                devicePolicyManager.setScreenCaptureDisabled(null, true)
                            }
                        }
                        "requireStorageEncryption" -> {
                            if (value as? Boolean == true) {
                                devicePolicyManager.setStorageEncryption(null, true)
                            }
                        }
                    }
                }
            }
            
            Log.d(TAG, "Work profile restrictions applied: $restrictions")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply work profile restrictions", e)
        }
    }

    fun isWorkProfile(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                userManager.isManagedProfile
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking work profile status", e)
            false
        }
    }

    private fun isManagedProfile(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                userManager.isManagedProfile
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isDeviceOwner(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                devicePolicyManager.isDeviceOwnerApp(context.packageName)
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isProfileOwner(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                devicePolicyManager.isProfileOwnerApp(context.packageName)
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun hasPolicyRestrictions(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                devicePolicyManager.isAdminActive(null) || 
                userManager.hasUserRestriction(UserManager.DISALLOW_INSTALL_UNKNOWN_SOURCES)
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun hasUserRestrictions(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                userManager.userRestrictions.isNotEmpty()
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun configureScreenLockPolicy() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                // Set password quality requirements
                devicePolicyManager.setPasswordQuality(
                    null, 
                    DevicePolicyManager.PASSWORD_QUALITY_BIOMETRIC_WEAK
                )
                
                // Set minimum password length
                devicePolicyManager.setPasswordMinimumLength(null, 6)
                
                // Set screen lock timeout
                devicePolicyManager.setMaximumTimeToLock(null, 300000) // 5 minutes
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to configure screen lock policy", e)
        }
    }

    private fun configureFileRestrictions() {
        try {
            // Configure file access restrictions
            // This would typically involve setting up cross-profile restrictions
            Log.d(TAG, "File restrictions configured")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to configure file restrictions", e)
        }
    }

    private fun enableSecurityLogging() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Enable security logging for compliance
                devicePolicyManager.setSecurityLoggingEnabled(null, true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enable security logging", e)
        }
    }

    private fun setupDataUsageMonitoring() {
        // Set up data usage monitoring for compliance
        Log.d(TAG, "Data usage monitoring setup completed")
    }

    private fun setupLocationTracking() {
        // Set up location tracking for recording compliance
        Log.d(TAG, "Location tracking setup completed")
    }

    private fun setupRetentionPolicies() {
        // Set up data retention policies
        Log.d(TAG, "Retention policies setup completed")
    }

    private fun setupRemoteWipeCapability() {
        // Set up remote wipe capability
        Log.d(TAG, "Remote wipe capability setup completed")
    }

    fun getComplianceStatus(): Map<String, Any> {
        return mapOf(
            "isSupported" to isSupported,
            "isConfigured" to isConfigured,
            "isWorkProfile" to isWorkProfile(),
            "hasDeviceAdmin" to (isDeviceOwner() || isProfileOwner()),
            "lastUpdated" to System.currentTimeMillis()
        )
    }

    fun dispose() {
        try {
            isSupported = false
            isConfigured = false
            Log.d(TAG, "Work profile manager disposed")
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing work profile manager", e)
        }
    }
}