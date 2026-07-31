# Flutter 核心类
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# 应用主类（MainActivity / NativeWebViewActivity / WebViewActivity）
-keep class com.qlapp.qinglong_app.** { *; }

# WebView 相关（webview_flutter 插件 + 原生 WebView）
-keep class android.webkit.** { *; }
-keep class com.tencent.smtt.** { *; } # 腾讯 X5 WebView（如有）
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# webview_flutter 插件
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# Kotlin 标准库与协程（R8 有时 会误删元数据）
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Gson / JSON 序列化（如用到反射）
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 保留反射调用的类（如 EventChannel / MethodChannel 关联的 Kotlin 类）
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
}
