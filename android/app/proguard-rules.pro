# Add project specific ProGuard rules here.
# Keep Whisper JNI classes
-keep class com.whispercpp.** { *; }

# Keep our service classes
-keep class com.localwhisper.android.service.** { *; }

# Keep model classes
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
