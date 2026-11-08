# youtubedl-android memetakan JSON yt-dlp ke class Kotlin lewat Jackson (refleksi).
# Tanpa aturan ini R8 mengacak/membuang class-nya dan init gagal di build release
# ("class w2 is not a concrete class", dicek di Infinix 9 Nov 2026).
-keep class com.yausername.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod,Exceptions
-dontwarn com.fasterxml.jackson.**

# Library ekstrak zip (python/ffmpeg) bawaan youtubedl-android.
-keep class org.apache.commons.compress.** { *; }
-dontwarn org.apache.commons.compress.**
