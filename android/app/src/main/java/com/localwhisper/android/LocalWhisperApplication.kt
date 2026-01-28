package com.localwhisper.android

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.localwhisper.android.transcription.WhisperManager

class LocalWhisperApplication : Application() {

    lateinit var whisperManager: WhisperManager
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this

        createNotificationChannels()
        whisperManager = WhisperManager(this)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val transcriptionChannel = NotificationChannel(
                CHANNEL_TRANSCRIPTION,
                "Transcription",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when voice transcription is active"
                setShowBadge(false)
            }

            val downloadChannel = NotificationChannel(
                CHANNEL_DOWNLOAD,
                "Model Download",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows model download progress"
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(transcriptionChannel)
            notificationManager.createNotificationChannel(downloadChannel)
        }
    }

    companion object {
        const val CHANNEL_TRANSCRIPTION = "transcription_channel"
        const val CHANNEL_DOWNLOAD = "download_channel"

        lateinit var instance: LocalWhisperApplication
            private set
    }
}
