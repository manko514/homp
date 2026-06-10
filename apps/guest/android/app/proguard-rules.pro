# Flutter/Dart proguard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep mobile_scanner
-keep class com.google.mlkit.** { *; }

# Keep Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
