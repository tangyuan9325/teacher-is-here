package com.example.flutter_application

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.widget.Toast
import kotlin.math.abs

class FloatingWindowService : Service() {

    private var floatingView: View? = null
    private var windowManager: WindowManager? = null
    private var params: WindowManager.LayoutParams? = null
    private var targetPackageName: String = ""
    private var lockMinutes: Int = 5
    private val handler = Handler(Looper.getMainLooper())
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isDragging = false

    companion object {
        var isRunning: Boolean = false
        private const val CHANNEL_ID = "floating_window_channel"
        private const val NOTIFICATION_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        targetPackageName = intent?.getStringExtra("packageName") ?: ""
        lockMinutes = intent?.getIntExtra("minutes", 5) ?: 5

        if (floatingView == null) {
            showFloatingWindow()
        } else {
            updateFloatingText()
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "老师来了悬浮窗",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "保持悬浮窗运行的前台服务通知"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("老师来了")
            .setContentText("悬浮窗运行中，点击开始专注")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun showFloatingWindow() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
        floatingView = inflater.inflate(R.layout.floating_window, null)

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 40
            y = 300
        }

        setupTouchListener()
        updateFloatingText()
        windowManager?.addView(floatingView, params)
    }

    private fun updateFloatingText() {
        floatingView?.findViewById<TextView>(R.id.floating_subtitle)?.text =
            if (targetPackageName.isNotEmpty()) "锁定 ${lockMinutes}分钟" else "点击开始专注"
    }

    private fun setupTouchListener() {
        floatingView?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (abs(dx) > 8 || abs(dy) > 8) {
                        isDragging = true
                        params?.x = initialX - dx
                        params?.y = initialY + dy
                        try {
                            windowManager?.updateViewLayout(floatingView, params)
                        } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        floatingView?.performClick()
                    } else {
                        snapToEdge()
                    }
                    true
                }
                else -> false
            }
        }

        floatingView?.setOnClickListener {
            launchAndLock()
        }
    }

    private fun snapToEdge() {
        val displayMetrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
        val screenWidth = displayMetrics.widthPixels
        val viewWidth = floatingView?.width ?: 0
        val centerX = (params?.x ?: 0) + viewWidth / 2

        params?.x = if (centerX < screenWidth / 2) {
            0
        } else {
            screenWidth - viewWidth - 20
        }
        try {
            windowManager?.updateViewLayout(floatingView, params)
        } catch (_: Exception) {}
    }

    private fun launchAndLock() {
        if (targetPackageName.isEmpty()) {
            Toast.makeText(this, "请先在应用中设置目标应用", Toast.LENGTH_SHORT).show()
            return
        }

        // 切换为激活状态（薄荷绿）
        floatingView?.setBackgroundResource(R.drawable.floating_window_bg_active)
        floatingView?.findViewById<TextView>(R.id.floating_title)?.text = "🔒 专注中"
        floatingView?.findViewById<TextView>(R.id.floating_subtitle)?.text = "${lockMinutes}分钟"

        // 1. 启动目标应用
        val launchIntent = packageManager.getLaunchIntentForPackage(targetPackageName)
        if (launchIntent != null) {
            launchIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            startActivity(launchIntent)
        } else {
            Toast.makeText(this, "无法启动目标应用", Toast.LENGTH_SHORT).show()
            return
        }

        // 2. 延迟后激活无障碍锁定
        handler.postDelayed({
            val lockIntent = Intent(this, LockAccessibilityService::class.java).apply {
                action = "LOCK_APP"
                putExtra("packageName", targetPackageName)
                putExtra("minutes", lockMinutes)
            }
            startService(lockIntent)
        }, 1500)

        Toast.makeText(this, "🔒 已锁定 ${lockMinutes} 分钟，老师正在看着你！", Toast.LENGTH_LONG).show()
    }

    fun stopFloatingWindow() {
        handler.removeCallbacksAndMessages(null)
        if (floatingView != null) {
            try {
                windowManager?.removeView(floatingView)
            } catch (_: Exception) {}
            floatingView = null
        }
        isRunning = false
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        if (floatingView != null) {
            try {
                windowManager?.removeView(floatingView)
            } catch (_: Exception) {}
            floatingView = null
        }
        isRunning = false
    }
}
