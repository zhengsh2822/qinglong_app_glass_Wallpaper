package com.qlapp.qinglong_app

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity

class WebViewActivity : FlutterActivity() {
    private var webView: WebView? = null

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowContentAccess = true
            settings.cacheMode = WebSettings.LOAD_DEFAULT
            webViewClient = WebViewClient()
        }
        setContentView(webView)
        webView?.loadUrl("file:///android_asset/codemirror.html")
    }

    override fun onDestroy() {
        webView?.destroy()
        super.onDestroy()
    }
}
