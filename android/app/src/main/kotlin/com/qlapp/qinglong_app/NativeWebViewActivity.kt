package com.qlapp.qinglong_app

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowInsetsController
import android.webkit.JavascriptInterface
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity

class NativeWebViewActivity : AppCompatActivity() {
    private var webView: WebView? = null
    private var editorContent = ""

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowContentAccess = true
            settings.cacheMode = WebSettings.LOAD_DEFAULT
            settings.defaultTextEncodingName = "utf-8"
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    val theme = intent.getStringExtra("theme") ?: "neat"
                    val mode = intent.getStringExtra("mode") ?: "shell"
                    val content = intent.getStringExtra("content") ?: ""
                    view?.postDelayed({
                        view.evaluateJavascript("initEditor('$theme','$mode')", null)
                        if (content.isNotEmpty()) {
                            val encoded = java.net.URLEncoder.encode(content, "UTF-8")
                            view.evaluateJavascript("editor.setValue(decodeURIComponent('$encoded'))", null)
                        }
                    }, 1000)
                }
            }
            addJavascriptInterface(object {
                @JavascriptInterface
                fun postMessage(value: String) {
                    editorContent = value
                }
            }, "MessageInvoker")
        }
        setContentView(webView)

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                val resultIntent = Intent().apply {
                    putExtra("content", editorContent)
                }
                setResult(RESULT_OK, resultIntent)
                finish()
            }
        })

        webView?.loadUrl("file:///android_asset/codemirror.html")
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window?.insetsController?.let {
                it.show(android.view.WindowInsets.Type.systemBars())
                it.setSystemBarsAppearance(
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                )
            }
        }
        window?.statusBarColor = android.graphics.Color.TRANSPARENT
        window?.navigationBarColor = android.graphics.Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window?.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window?.setDecorFitsSystemWindows(false)
        }
    }

    override fun onDestroy() {
        webView?.destroy()
        super.onDestroy()
    }
}
