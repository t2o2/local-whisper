package com.localwhisper.android.service

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.localwhisper.android.LocalWhisperApplication
import com.localwhisper.android.R
import com.localwhisper.android.audio.AudioData
import com.localwhisper.android.audio.AudioRecorder
import com.localwhisper.android.transcription.TranscriptionResult
import com.localwhisper.android.transcription.WhisperModel
import com.localwhisper.android.ui.MainActivity
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Foreground service for handling transcription operations.
 * Can be used for longer recordings or background processing.
 */
class TranscriptionService : Service() {

    private val binder = LocalBinder()
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private val audioRecorder = AudioRecorder()
    private var recordingJob: Job? = null

    private val _serviceState = MutableStateFlow<ServiceState>(ServiceState.Idle)
    val serviceState: StateFlow<ServiceState> = _serviceState.asStateFlow()

    private val _lastTranscription = MutableStateFlow<String?>(null)
    val lastTranscription: StateFlow<String?> = _lastTranscription.asStateFlow()

    private val whisperManager
        get() = (application as LocalWhisperApplication).whisperManager

    inner class LocalBinder : Binder() {
        fun getService(): TranscriptionService = this@TranscriptionService
    }

    override fun onBind(intent: Intent): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "TranscriptionService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_RECORDING -> startRecordingForeground()
            ACTION_STOP_RECORDING -> stopRecordingAndTranscribe()
            ACTION_CANCEL -> cancelAndStop()
        }
        return START_NOT_STICKY
    }

    private fun startRecordingForeground() {
        startForeground(NOTIFICATION_ID, createRecordingNotification())

        _serviceState.value = ServiceState.Recording

        recordingJob = serviceScope.launch {
            val started = audioRecorder.startRecording()
            if (!started) {
                _serviceState.value = ServiceState.Error("Failed to start recording")
                stopSelf()
                return@launch
            }

            // Continuously read audio
            while (isActive && audioRecorder.isCurrentlyRecording) {
                audioRecorder.readAudioChunk()
                delay(50)
            }
        }
    }

    private fun stopRecordingAndTranscribe() {
        recordingJob?.cancel()
        recordingJob = null

        serviceScope.launch {
            _serviceState.value = ServiceState.Transcribing
            updateNotification(createTranscribingNotification())

            val audioData = audioRecorder.stopRecording()

            if (audioData == null || audioData.isTooShort) {
                _serviceState.value = ServiceState.Error("Recording too short")
                stopSelf()
                return@launch
            }

            when (val result = whisperManager.transcribe(audioData)) {
                is TranscriptionResult.Success -> {
                    _lastTranscription.value = result.text
                    _serviceState.value = ServiceState.Complete(result.text)
                }
                is TranscriptionResult.Error -> {
                    _serviceState.value = ServiceState.Error(result.message)
                }
            }

            stopSelf()
        }
    }

    private fun cancelAndStop() {
        recordingJob?.cancel()
        audioRecorder.cancelRecording()
        _serviceState.value = ServiceState.Idle
        stopSelf()
    }

    private fun createRecordingNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, LocalWhisperApplication.CHANNEL_TRANSCRIPTION)
            .setContentTitle("Recording")
            .setContentText("Tap to open LocalWhisper")
            .setSmallIcon(R.drawable.ic_mic)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(
                R.drawable.ic_stop,
                "Stop",
                PendingIntent.getService(
                    this,
                    1,
                    Intent(this, TranscriptionService::class.java).apply {
                        action = ACTION_STOP_RECORDING
                    },
                    PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()
    }

    private fun createTranscribingNotification(): Notification {
        return NotificationCompat.Builder(this, LocalWhisperApplication.CHANNEL_TRANSCRIPTION)
            .setContentTitle("Transcribing")
            .setContentText("Processing audio...")
            .setSmallIcon(R.drawable.ic_mic)
            .setOngoing(true)
            .setProgress(0, 0, true)
            .build()
    }

    private fun updateNotification(notification: Notification) {
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        audioRecorder.cancelRecording()
        Log.d(TAG, "TranscriptionService destroyed")
    }

    companion object {
        private const val TAG = "TranscriptionService"
        private const val NOTIFICATION_ID = 1

        const val ACTION_START_RECORDING = "com.localwhisper.START_RECORDING"
        const val ACTION_STOP_RECORDING = "com.localwhisper.STOP_RECORDING"
        const val ACTION_CANCEL = "com.localwhisper.CANCEL"
    }
}

sealed class ServiceState {
    object Idle : ServiceState()
    object Recording : ServiceState()
    object Transcribing : ServiceState()
    data class Complete(val text: String) : ServiceState()
    data class Error(val message: String) : ServiceState()
}
