# Flutter/Dart proguard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
