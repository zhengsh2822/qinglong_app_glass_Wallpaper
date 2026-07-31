package com.qlapp.qinglong_app

import android.annotation.SuppressLint
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.Telephony
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.WindowCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val SHARE_CHANNEL = "com.qlapp.qinglong_app/share"
    private val FILE_PICKER_CHANNEL = "com.qlapp.qinglong_app/file_picker"
    private val WEBVIEW_CHANNEL = "com.qlapp.qinglong_app/webview"
    private val COOKIE_CHANNEL = "com.qlapp.qinglong_app/cookies"
    private val SMS_CHANNEL = "com.qlapp.qinglong_app/sms"
    private val FLOATING_CLOCK_CHANNEL = "com.qlapp.qinglong_app/floating_clock"
    private val LIFECYCLE_CHANNEL = "com.qlapp.qinglong_app/lifecycle"
    private var filePickerResult: MethodChannel.Result? = null
    private var webViewResult: MethodChannel.Result? = null
    private val FILE_PICKER_REQUEST_CODE = 1001
    private val WEBVIEW_REQUEST_CODE = 1002

    private var smsSink: EventChannel.EventSink? = null
    private var smsReceiver: BroadcastReceiver? = null

    // 金标联盟公平调度：应用前后台生命周期 EventSink
    // Flutter 端订阅后，应用进入后台/前台时会收到事件，用于暂停/恢复 Timer.periodic 轮询
    private var lifecycleSink: EventChannel.EventSink? = null
    private var processLifecycleObserver: DefaultLifecycleObserver? = null

    // 悬浮时钟相关
    private var floatingView: FrameLayout? = null
    private var floatingWindowManager: WindowManager? = null
    private var floatingParams: WindowManager.LayoutParams? = null
    private var timeTextView: TextView? = null
    private var lastSecond = -1
    private var lastMillis = -1

    // 悬浮时钟时间刷新 Handler
    // 使用 Handler.postDelayed 而非 Choreographer.postFrameCallback：
    // Choreographer 与屏幕渲染帧同步，应用在后台时无渲染帧不会触发，导致后台时间停止；
    // Handler 基于 Looper 消息循环，应用在后台时主线程 Looper 仍会处理消息，可保持后台刷新。
    private val timeHandler = Handler(Looper.getMainLooper())
    private val timeRunnable = object : Runnable {
        override fun run() {
            // Activity 已销毁或悬浮窗已移除时，不再继续 post，避免崩溃
            if (isDestroyed || isFinishing || floatingView == null) return
            try {
                val now = java.util.Calendar.getInstance()
                val sec = now.get(java.util.Calendar.SECOND)
                val millis = now.get(java.util.Calendar.MILLISECOND)
                if (sec != lastSecond || millis != lastMillis) {
                    lastSecond = sec
                    lastMillis = millis
                    timeTextView?.text = formatTimeWithMillis(now)
                }
                // 50ms 刷新间隔（约 20fps），保证毫秒显示流畅且不占用过多资源
                timeHandler.postDelayed(this, 50)
            } catch (e: Exception) {
                // 任何异常都不再继续 post，避免循环崩溃
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "share") {
                val text = call.argument<String>("text") ?: ""
                val intent = Intent(Intent.ACTION_SEND)
                intent.type = "text/plain"
                intent.putExtra(Intent.EXTRA_TEXT, text)
                intent.putExtra(Intent.EXTRA_SUBJECT, "青龙客户端分享")
                startActivity(Intent.createChooser(intent, "分享"))
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEBVIEW_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openEditor") {
                webViewResult = result
                val intent = Intent(this, NativeWebViewActivity::class.java).apply {
                    putExtra("theme", call.argument<String>("theme") ?: "neat")
                    putExtra("mode", call.argument<String>("mode") ?: "shell")
                    putExtra("content", call.argument<String>("content") ?: "")
                }
                startActivityForResult(intent, WEBVIEW_REQUEST_CODE)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_PICKER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickFile") {
                filePickerResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                startActivityForResult(intent, FILE_PICKER_REQUEST_CODE)
            } else {
                result.notImplemented()
            }
        }

        // Cookie 提取通道 - 供京东Cookie助手使用
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COOKIE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCookies") {
                val url = call.argument<String>("url") ?: ""
                try {
                    val cookieManager = android.webkit.CookieManager.getInstance()
                    val cookies = cookieManager.getCookie(url)
                    result.success(cookies)
                } catch (e: Exception) {
                    result.success("")
                }
            } else {
                result.notImplemented()
            }
        }

        // 短信验证码监听通道 - 供京东Cookie助手使用
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsSink = events
                    registerSmsReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterSmsReceiver()
                    smsSink = null
                }
            }
        )

        // 悬浮时钟通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_CLOCK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startFloating" -> { startFloatingWindow(); result.success(true) }
                "stopFloating" -> { stopFloatingWindow(); result.success(true) }
                "canDrawOverlays" -> { result.success(canDrawOverlays()) }
                "requestOverlayPermission" -> { requestOverlayPermission(); result.success(true) }
                else -> result.notImplemented()
            }
        }

        // 金标联盟公平调度：应用前后台生命周期通道
        // Flutter 端订阅后，应用进入后台/前台/内存压力时会收到事件
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LIFECYCLE_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    lifecycleSink = events
                    // 立即推送当前状态，避免订阅时机晚于状态切换导致 Flutter 端状态不同步
                    val isForeground = ProcessLifecycleOwner
                        .get().lifecycle.currentState
                        .isAtLeast(androidx.lifecycle.Lifecycle.State.STARTED)
                    events?.success(if (isForeground) "foreground" else "background")
                }

                override fun onCancel(arguments: Any?) {
                    lifecycleSink = null
                }
            }
        )
    }

    private fun registerSmsReceiver() {
        if (smsReceiver != null) return
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                    val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                    val sb = StringBuilder()
                    for (msg in messages) {
                        sb.append(msg.displayMessageBody)
                    }
                    val body = sb.toString()
                    // 提取验证码：匹配 4-8 位数字
                    val regex = Regex("(?:验证码|校验码|验证码为|code)[^0-9]*(\\d{4,8})|(\\d{4,8})[^0-9]*(?:验证码|校验码)")
                    val match = regex.find(body)
                    val code = match?.groupValues?.firstOrNull { it.isNotEmpty() && it.length in 4..8 }
                    if (code != null) {
                        smsSink?.success(code)
                    }
                }
            }
        }
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(smsReceiver, filter)
        }
    }

    private fun unregisterSmsReceiver() {
        if (smsReceiver != null) {
            try {
                unregisterReceiver(smsReceiver)
            } catch (e: Exception) {
                // ignore
            }
            smsReceiver = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FILE_PICKER_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                
                // Get file name
                var fileName = "unknown"
                if (uri.scheme == "content") {
                    val cursor = contentResolver.query(uri, null, null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val nameIndex = it.getColumnIndex("_display_name")
                            if (nameIndex >= 0) {
                                fileName = it.getString(nameIndex) ?: "unknown"
                            }
                        }
                    }
                }
                
                // Copy content URI to temp file
                try {
                    val tempDir = File(cacheDir, "picked_files")
                    if (!tempDir.exists()) tempDir.mkdirs()
                    val tempFile = File(tempDir, fileName)
                    
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(tempFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    
                    val resultMap = HashMap<String, String>()
                    resultMap["path"] = tempFile.absolutePath
                    resultMap["name"] = fileName
                    filePickerResult?.success(resultMap)
                } catch (e: Exception) {
                    filePickerResult?.success(null)
                }
            } else {
                filePickerResult?.success(null)
            }
            filePickerResult = null
        }
        if (requestCode == WEBVIEW_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val content = data.getStringExtra("content") ?: ""
                webViewResult?.success(content)
            } else {
                webViewResult?.success(null)
            }
            webViewResult = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let {
                it.show(android.view.WindowInsets.Type.systemBars())
                it.setSystemBarsAppearance(
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                )
            }
        }
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }
        registerProcessLifecycleObserver()
    }

    /**
     * 金标联盟公平调度：注册 ProcessLifecycleObserver
     *
     * ProcessLifecycleOwner 监听整个应用进程的前后台切换（不是单个 Activity）。
     * 当应用所有 Activity 都进入后台时，触发 ON_STOP；当任意 Activity 回到前台时，触发 ON_START。
     *
     * 我们在此将前后台事件通过 EventChannel 推送给 Flutter 端，让 Flutter 端的
     * Timer.periodic 轮询（intime_log 页面每 2 秒刷新日志）在应用进入后台时立即暂停，
     * 避免在后台无意义地占用 CPU 和网络资源，符合金标联盟公平调度要求。
     */
    private fun registerProcessLifecycleObserver() {
        processLifecycleObserver = object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                // 应用回到前台
                lifecycleSink?.success("foreground")
            }

            override fun onStop(owner: LifecycleOwner) {
                // 应用进入后台
                lifecycleSink?.success("background")
            }
        }
        processLifecycleObserver?.let {
            ProcessLifecycleOwner.get().lifecycle.addObserver(it)
        }
    }

    /**
     * 金标联盟公平调度：响应系统内存压力
     *
     * 系统内存紧张时回调，应用应释放不必要的内存资源。
     * - TRIM_MEMORY_UI_HIDDEN：UI 已不可见，可释放 UI 相关资源
     * - TRIM_MEMORY_RUNNING_LOW：内存紧张，可释放缓存
     * - TRIM_MEMORY_COMPLETE：内存极度紧张，可能被杀，尽力释放
     */
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        when (level) {
            ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN -> {
                // 应用进入后台，UI 不可见
                // Flutter 端会通过 ProcessLifecycleObserver 收到 background 事件
            }
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW,
            ComponentCallbacks2.TRIM_MEMORY_COMPLETE -> {
                // 内存紧张，触发 Flutter 端清理缓存
                // 通过 lifecycleSink 复用同一个 channel 推送内存压力事件
                lifecycleSink?.success("memory_pressure")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterSmsReceiver()
        stopFloatingWindow()
        // 移除 ProcessLifecycleObserver，避免内存泄漏
        processLifecycleObserver?.let {
            ProcessLifecycleOwner.get().lifecycle.removeObserver(it)
        }
        processLifecycleObserver = null
        lifecycleSink = null
    }

    // ==================== 悬浮时钟实现 ====================

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun startFloatingWindow() {
        if (!canDrawOverlays()) { requestOverlayPermission(); return }
        if (floatingView != null) return

        floatingWindowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
        }

        floatingParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 100
            y = 200
        }

        val sampleText = "00:00:00.000"
        val textPaint = android.graphics.Paint().apply {
            typeface = Typeface.MONOSPACE
            textSize = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP, 18f, resources.displayMetrics
            )
        }
        val measuredTextWidth = textPaint.measureText(sampleText)

        timeTextView = TextView(this).apply {
            setTextColor(0xFFFFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.MONOSPACE
            text = formatTimeWithMillis(java.util.Calendar.getInstance())
            setShadowLayer(3f, 0f, 0f, 0x88000000.toInt())
            setLayerType(View.LAYER_TYPE_HARDWARE, null)
            includeFontPadding = false
            setPadding(0, 0, 4, 0)
            minWidth = Math.ceil(measuredTextWidth.toDouble()).toInt()
        }

        val closeBtn = TextView(this).apply {
            setTextColor(0xCCFFFFFF.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            text = "\u2715"
            setPadding(8, 6, 8, 6)
            setLayerType(View.LAYER_TYPE_HARDWARE, null)
            includeFontPadding = false
            setOnClickListener { stopFloatingWindow() }
        }

        val contentRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(timeTextView)
            addView(closeBtn)
        }

        val capsuleBackground = GradientDrawable().apply {
            setColor(0xE6000000.toInt())
            cornerRadius = 100f
            setStroke(1, 0x6618D5D5.toInt())
        }

        floatingView = FrameLayout(this).apply {
            background = capsuleBackground
            setPadding(12, 8, 4, 8)
            setLayerType(View.LAYER_TYPE_HARDWARE, null)
            addView(contentRow)
        }

        var baseX = 0
        var baseY = 0
        var touchStartX = 0f
        var touchStartY = 0f
        var touchSlop = android.view.ViewConfiguration.get(this).scaledTouchSlop
        var isDragging = false

        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels

        floatingView?.post {
            val viewWidth = floatingView?.width ?: 0
            val viewHeight = floatingView?.height ?: 0
            floatingParams?.let { p ->
                p.x = p.x.coerceIn(0, screenWidth - viewWidth)
                p.y = p.y.coerceIn(0, screenHeight - viewHeight)
                floatingWindowManager?.updateViewLayout(floatingView, p)
            }
        }

        floatingView?.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    baseX = floatingParams!!.x
                    baseY = floatingParams!!.y
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    isDragging = false
                    v.alpha = 0.85f
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchStartX
                    val dy = event.rawY - touchStartY
                    if (!isDragging && (Math.abs(dx) > touchSlop || Math.abs(dy) > touchSlop)) {
                        isDragging = true
                    }
                    if (isDragging) {
                        val maxX = (screenWidth - v.width).coerceAtLeast(0)
                        val maxY = (screenHeight - v.height).coerceAtLeast(0)
                        floatingParams!!.x = (baseX + dx.toInt()).coerceIn(0, maxX)
                        floatingParams!!.y = (baseY + dy.toInt()).coerceIn(0, maxY)
                        floatingWindowManager?.updateViewLayout(floatingView, floatingParams)
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.alpha = 1.0f
                    isDragging = false
                    true
                }
                else -> false
            }
        }

        floatingWindowManager?.addView(floatingView, floatingParams)
        timeHandler.post(timeRunnable)
    }

    private fun formatTimeWithMillis(cal: java.util.Calendar): String {
        val h = cal.get(java.util.Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
        val m = cal.get(java.util.Calendar.MINUTE).toString().padStart(2, '0')
        val s = cal.get(java.util.Calendar.SECOND).toString().padStart(2, '0')
        val ms = cal.get(java.util.Calendar.MILLISECOND).toString().padStart(3, '0')
        return "$h:$m:$s.$ms"
    }

    private fun stopFloatingWindow() {
        timeHandler.removeCallbacks(timeRunnable)
        try {
            floatingView?.let { floatingWindowManager?.removeView(it) }
        } catch (e: Exception) {
            // removeView 可能因 view 已被移除或 window token 失效而抛异常
        }
        floatingView = null
        timeTextView = null
    }
}
