# Flutter Engine Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# General ProGuard attributes
-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature
-keepattributes SourceFile,LineNumberTable
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**

# Google Sign-In & Play Services (still used by google_sign_in package)
-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# AndroidX and Shared Preferences
-keep class androidx.annotation.** { *; }
-keep class androidx.core.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# JNI & Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable and Serializable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
