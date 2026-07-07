# youtubedl-android: JNI・リフレクション経由で使われるため難読化/削除しない
-keep class com.yausername.** { *; }
-dontwarn com.yausername.**

# youtubedl-android の ZipUtils が使う commons-compress は
# ZipExtraField 実装をリフレクションで生成するため難読化すると
# "is not a concrete class" で起動時クラッシュする
-keep class org.apache.commons.compress.** { *; }
-dontwarn org.apache.commons.compress.**

# ffmpeg-kit / smart-exception: JNIコールバックで使われる
-keep class com.arthenica.** { *; }
-dontwarn com.arthenica.**

# youtubedl-android が内部で使う Jackson (JSONマッピングはリフレクション依存)
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*

# Flutter プラグイン (MethodChannel 経由)
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**
