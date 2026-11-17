# Keep Kotlin metadata used by reflection in coroutines/serialization-free code.
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions
-dontwarn kotlinx.coroutines.**
-dontwarn okhttp3.**
-dontwarn okio.**

# OkHttp / Okio platform pieces
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Compose is reflection-light, but keep the compose runtime entries.
-keep class androidx.compose.runtime.** { *; }
