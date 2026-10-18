# Aturan minimal supaya minifyEnabled tidak merusak library yang pakai
# reflection (Firebase, Firestore, Gson). Flutter engine sendiri sudah
# di-keep otomatis oleh Flutter Gradle plugin.

# Firebase / Firestore / gRPC (dipakai untuk deserialize dokumen ke model)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Kalau ada model class kamu sendiri yang di-deserialize otomatis dari
# Firestore lewat withConverter()/toJson(), tambahkan keep rule per
# package model di sini, misalnya:
# -keep class com.pertamina.kmj.project_otp_kmj.models.** { *; }

# Kotlin metadata (hindari warning berlebihan, tidak wajib tapi rapi)
-dontwarn kotlin.**
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
