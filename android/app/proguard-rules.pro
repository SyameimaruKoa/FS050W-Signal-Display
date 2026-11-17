# Compose's Color/ColorSpaces rely on a static color-space lookup table that
# R8 can mis-optimize (ArrayIndexOutOfBoundsException in getColorSpace-impl).
-keep class androidx.compose.ui.graphics.Color { *; }
-keep class androidx.compose.ui.graphics.Color$Companion { *; }
-keep class androidx.compose.ui.graphics.colorspace.ColorSpaces { *; }
-keep class androidx.compose.ui.graphics.colorspace.ColorSpace { *; }
-keep class androidx.compose.ui.graphics.colorspace.Rgb { *; }

# Keep Compose runtime metadata used by the compiler-generated code.
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions, SourceDebugExtension
-dontwarn kotlinx.coroutines.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
