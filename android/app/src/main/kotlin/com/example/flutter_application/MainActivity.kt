package com.example.flutter_application

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.flutter_application/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppList" -> {
                    result.success(getInstalledApps())
                }
                "hasOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "requestOverlayPermission" -> {
                    startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                    result.success(null)
                }
                "hasAccessibilityPermission" -> {
                    result.success(isAccessibilityEnabled())
                }
                "requestAccessibilityPermission" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "requestBatteryOptimization" -> {
                    requestIgnoreBatteryOptimization()
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "startFloatingWindow" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val minutes = call.argument<Int>("minutes") ?: 5

                    if (!hasOverlayPermission()) {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                        result.error("NO_PERMISSION", "请授予悬浮窗权限", null)
                        return@setMethodCallHandler
                    }

                    val serviceIntent = Intent(this, FloatingWindowService::class.java).apply {
                        putExtra("packageName", packageName)
                        putExtra("minutes", minutes)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success("Started")
                }
                "stopFloatingWindow" -> {
                    val serviceIntent = Intent(this, FloatingWindowService::class.java)
                    stopService(serviceIntent)
                    val lockIntent = Intent(this, LockAccessibilityService::class.java).apply {
                        action = "UNLOCK_APP"
                    }
                    stopService(lockIntent)
                    result.success("Stopped")
                }
                "isServiceRunning" -> {
                    result.success(FloatingWindowService.isRunning)
                }
                "isLocking" -> {
                    result.success(LockAccessibilityService.isLocking)
                }
                "getLockRemainingSeconds" -> {
                    result.success(LockAccessibilityService.remainingSeconds)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val apps = pm.getInstalledApplications(android.content.pm.PackageManager.GET_META_DATA)
        return apps
            .filter { pm.getLaunchIntentForPackage(it.packageName) != null }
            .sortedBy { pm.getApplicationLabel(it).toString() }
            .map {
                mapOf(
                    "name" to pm.getApplicationLabel(it).toString(),
                    "package" to it.packageName
                )
            }
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun isAccessibilityEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains("${packageName}/${LockAccessibilityService::class.java.name}")
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else true
    }

    private fun requestIgnoreBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = android.net.Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }
}
