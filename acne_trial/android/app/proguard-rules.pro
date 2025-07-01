# === TensorFlow Lite GPU Delegate Fix ===
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Prevent R8 from removing used native delegates
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep class org.tensorflow.lite.support.** { *; }
-keep class org.tensorflow.lite.delegate.** { *; }