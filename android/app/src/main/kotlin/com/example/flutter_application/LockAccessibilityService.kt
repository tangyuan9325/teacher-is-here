package com.example.flutter_application

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

class LockAccessibilityService : AccessibilityService() {

    private var targetPackageName: String = ""
    private var lockEndTime: Long = 0
    private var lockMinutes: Int = 0
    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var watchdogRunnable: Runnable? = null
    private var countdownRunnable: Runnable? = null
    private var lastRelaunchTime: Long = 0

    companion object {
        var isLocking: Boolean = false
        var currentTargetPackage: String = ""
        var remainingSeconds: Int = 0
        private const val CHANNEL_ID = "lock_service_channel"
        private const val NOTIFICATION_ID = 2002
        private const val RELAUNCH_COOLDOWN_MS = 300L
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 50
        }
        serviceInfo = info
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "LOCK_APP" -> {
                targetPackageName = intent.getStringExtra("packageName") ?: ""
                lockMinutes = intent.getIntExtra("minutes", 5)
                lockEndTime = System.currentTimeMillis() + (lockMinutes * 60 * 1000L)
                currentTargetPackage = targetPackageName
                isLocking = true
                remainingSeconds = lockMinutes * 60

                createNotificationChannel()
                startForeground(NOTIFICATION_ID, buildLockNotification())

                acquireWakeLock()
                startWatchdog()
                startCountdown()

                Toast.makeText(this, "🔒 已锁定 ${lockMinutes} 分钟，老师来了！", Toast.LENGTH_LONG).show()
            }
            "UNLOCK_APP" -> {
                unlockApp()
            }
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "专注锁定服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "专注期间保持应用锁定"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildLockNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("🔒 专注中")
            .setContentText("剩余 ${remainingSeconds / 60}分${remainingSeconds % 60}秒，请勿退出")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification() {
        val notification = buildLockNotification()
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                "TeacherIsHere:WakeLock"
            )
            wakeLock?.acquire(lockMinutes * 60 * 1000L + 10000)
        } catch (_: Exception) {}
    }

    /**
     * 看门狗：每 500ms 检查一次当前前台应用，
     * 如果不是目标应用则立即拉回。作为无障碍事件的兜底机制。
     */
    private fun startWatchdog() {
        watchdogRunnable = object : Runnable {
            override fun run() {
                if (!isLocking) return
                val remainingMs = lockEndTime - System.currentTimeMillis()
                if (remainingMs <= 0) {
                    unlockApp()
                    return
                }
                enforceLock()
                handler.postDelayed(this, 500)
            }
        }
        handler.post(watchdogRunnable!!)
    }

    private fun startCountdown() {
        countdownRunnable = object : Runnable {
            override fun run() {
                if (!isLocking) return
                remainingSeconds = ((lockEndTime - System.currentTimeMillis()) / 1000).toInt()
                if (remainingSeconds <= 0) {
                    unlockApp()
                    return
                }
                if (remainingSeconds % 10 == 0) {
                    updateNotification()
                }
                handler.postDelayed(this, 1000)
            }
        }
        handler.post(countdownRunnable!!)
    }

    /**
     * 核心锁定逻辑：检查当前前台应用，如果不是目标应用则立即拉回。
     * 使用多种检测方式确保可靠性。
     */
    private fun enforceLock() {
        if (targetPackageName.isEmpty()) return

        val currentPackage = getForegroundPackage()
        if (currentPackage != targetPackageName && currentPackage != packageName) {
            // 冷却时间内不重复启动，避免无限循环
            val now = System.currentTimeMillis()
            if (now - lastRelaunchTime > RELAUNCH_COOLDOWN_MS) {
                lastRelaunchTime = now
                vibrateOnEscape()
                relaunchTargetApp()
            }
        }
    }

    private fun getForegroundPackage(): String? {
        // 优先使用 UsageStatsManager（Android 5.0+ 推荐方式，需 PACKAGE_USAGE_STATS 权限）
        // 回退到无障碍事件检测（本服务已监听 TYPE_WINDOW_STATE_CHANGED）
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            // 查询最近 10 秒内的使用统计
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, now - 10000, now)
            if (stats != null && stats.isNotEmpty()) {
                // 找到最近时间戳的应用
                var recentPkg: String? = null
                var recentTime = 0L
                for (us in stats) {
                    if (us.lastTimeUsed > recentTime) {
                        recentTime = us.lastTimeUsed
                        recentPkg = us.packageName
                    }
                }
                recentPkg
            } else {
                // UsageStatsManager 无数据（可能未授权），回退到 getRunningTasks
                @Suppress("DEPRECATION")
                val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                @Suppress("DEPRECATION")
                val tasks = am.getRunningTasks(1)
                if (tasks.isNotEmpty()) {
                    tasks[0].topActivity?.packageName
                } else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun relaunchTargetApp() {
        try {
            val intent = packageManager.getLaunchIntentForPackage(targetPackageName)
            if (intent != null) {
                intent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
                )
                startActivity(intent)
            }
        } catch (e: Exception) {
            // 如果无法启动，尝试从最近任务恢复
            try {
                @Suppress("DEPRECATION")
                performGlobalAction(GLOBAL_ACTION_RECENTS)
                handler.postDelayed({
                    try {
                        val intent = packageManager.getLaunchIntentForPackage(targetPackageName)
                        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (_: Exception) {}
                }, 300)
            } catch (_: Exception) {}
        }
    }

    private fun vibrateOnEscape() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator.vibrate(
                    VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(100)
                }
            }
        } catch (_: Exception) {}
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isLocking || event == null) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val pkg = event.packageName?.toString()
                // 如果窗口变化到非目标应用，立即拉回
                if (pkg != null && pkg != targetPackageName && pkg != packageName) {
                    // 排除系统UI（状态栏、输入法等）
                    if (!isSystemPackage(pkg)) {
                        val now = System.currentTimeMillis()
                        if (now - lastRelaunchTime > RELAUNCH_COOLDOWN_MS) {
                            lastRelaunchTime = now
                            vibrateOnEscape()
                            relaunchTargetApp()
                        }
                    }
                }
            }
        }
    }

    private fun isSystemPackage(pkg: String): Boolean {
        return pkg.startsWith("com.android.") ||
                pkg.startsWith("android.") ||
                pkg == "com.android.systemui" ||
                pkg.contains("inputmethod") ||
                pkg.contains("wallpaper")
    }

    override fun onInterrupt() {}

    private fun unlockApp() {
        isLocking = false
        currentTargetPackage = ""
        watchdogRunnable?.let { handler.removeCallbacks(it) }
        countdownRunnable?.let { handler.removeCallbacks(it) }
        watchdogRunnable = null
        countdownRunnable = null

        try {
            wakeLock?.release()
        } catch (_: Exception) {}
        wakeLock = null

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {}

        // 通知悬浮窗服务也停止
        val stopIntent = Intent(this, FloatingWindowService::class.java)
        stopService(stopIntent)

        Toast.makeText(this, "🎉 专注结束！老师走了，已解锁", Toast.LENGTH_LONG).show()
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        isLocking = false
        currentTargetPackage = ""
        watchdogRunnable?.let { handler.removeCallbacks(it) }
        countdownRunnable?.let { handler.removeCallbacks(it) }
        try {
            wakeLock?.release()
        } catch (_: Exception) {}
    }
}
