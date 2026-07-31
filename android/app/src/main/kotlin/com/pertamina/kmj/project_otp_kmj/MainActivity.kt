package com.pertamina.kmj.project_otp_kmj

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = 
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // =============================================
            // CHANNEL 1: OVERTIME PRIORITY (SUARA OTP CUSTOM)
            // =============================================
            val overtimeChannel = NotificationChannel(
                "otp_overtime_priority",
                "OTP Lembur Prioritas",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi pengajuan, persetujuan, dan penugasan lembur"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                
                // SUARA CUSTOM OTP DARI FOLDER RAW
                val customSound = Uri.parse(
                    "android.resource://${packageName}/raw/otp_notification"
                )
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(customSound, audioAttributes)
            }

            // =============================================
            // CHANNEL 2: GENERAL (SUARA DEFAULT)
            // =============================================
            val generalChannel = NotificationChannel(
                "otp_general",
                "OTP Notifikasi Umum",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Notifikasi informasi dan pengingat umum"
                setSound(null, null)
            }

            // =============================================
            // REGISTER SEMUA CHANNEL
            // =============================================
            notificationManager.createNotificationChannel(overtimeChannel)
            notificationManager.createNotificationChannel(generalChannel)
            
            debugPrint("✅ Notification channels created successfully")
        }
    }
}

// Buat debugPrint di Kotlin (opsional)
fun debugPrint(message: String) {
    android.util.Log.d("MainActivity", message)
}