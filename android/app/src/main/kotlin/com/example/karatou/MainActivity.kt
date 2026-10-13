package com.karatou.android

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createPushChannel()
    }

    // Canal des notifications push FCM. Son identifiant est celui que le
    // backend envoie (`ANDROID_CHANNEL_ID` dans fcm-sender.service.ts) et que
    // le manifeste déclare par défaut : sans lui, Android range tout dans
    // « Divers ». Recréer un canal existant est sans effet.
    private fun createPushChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            PUSH_CHANNEL_ID,
            "Notifications KPB",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Bourses, échéances et messages de ton conseiller"
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    companion object {
        private const val PUSH_CHANNEL_ID = "kpb_default"
    }
}
