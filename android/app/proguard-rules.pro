# ── Mixpanel ────────────────────────────────────────────────────────────────
-keep class com.mixpanel.** { *; }
-keepclassmembers class com.mixpanel.** { *; }
-dontwarn com.mixpanel.**
-keep class com.mixpanel.android.** { *; }
-keepclassmembers class com.mixpanel.android.** { *; }
-dontwarn com.mixpanel.android.**

# Google Play Services (used by Mixpanel for certain device properties)
-keep class com.google.android.gms.ads.identifier.** { *; }
-dontwarn com.google.android.gms.ads.identifier.**

# ── RevenueCat ───────────────────────────────────────────────────────────────
-keep class com.revenuecat.** { *; }
-keepclassmembers class com.revenuecat.** { *; }
-dontwarn com.revenuecat.**

# ── Supabase / OkHttp / Ktor ─────────────────────────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# ── Flutter / Dart JNI ───────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Keep enums (required by many SDKs) ──────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Serialization (Gson / JSON) ─────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
