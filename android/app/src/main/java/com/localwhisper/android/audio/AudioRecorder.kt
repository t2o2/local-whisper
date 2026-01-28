package com.localwhisper.android.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Audio recorder that captures microphone input in Whisper-compatible format.
 * Records at 16kHz mono, which is what Whisper expects.
 */
class AudioRecorder {

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private val audioBuffer = mutableListOf<Float>()

    val isCurrentlyRecording: Boolean
        get() = isRecording

    /**
     * Start recording audio from the microphone.
     * Must be called from a coroutine context.
     */
    @SuppressLint("MissingPermission")
    suspend fun startRecording(): Boolean = withContext(Dispatchers.IO) {
        if (isRecording) {
            Log.w(TAG, "Already recording")
            return@withContext false
        }

        try {
            val bufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT
            )

            if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
                Log.e(TAG, "Invalid buffer size: $bufferSize")
                return@withContext false
            }

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize * 2
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize")
                audioRecord?.release()
                audioRecord = null
                return@withContext false
            }

            audioBuffer.clear()
            audioRecord?.startRecording()
            isRecording = true

            Log.d(TAG, "Recording started at ${SAMPLE_RATE}Hz")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            audioRecord?.release()
            audioRecord = null
            false
        }
    }

    /**
     * Read audio samples into the buffer.
     * Should be called repeatedly while recording.
     */
    suspend fun readAudioChunk(): Boolean = withContext(Dispatchers.IO) {
        if (!isRecording || audioRecord == null) {
            return@withContext false
        }

        try {
            val shortBuffer = ShortArray(CHUNK_SIZE)
            val shortsRead = audioRecord?.read(shortBuffer, 0, CHUNK_SIZE) ?: -1

            if (shortsRead > 0) {
                // Convert shorts to floats (normalized to -1.0 to 1.0)
                for (i in 0 until shortsRead) {
                    audioBuffer.add(shortBuffer[i] / 32768.0f)
                }
                true
            } else {
                Log.w(TAG, "Read returned: $shortsRead")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading audio", e)
            false
        }
    }

    /**
     * Stop recording and return the captured audio data.
     */
    suspend fun stopRecording(): AudioData? = withContext(Dispatchers.IO) {
        if (!isRecording) {
            Log.w(TAG, "Not currently recording")
            return@withContext null
        }

        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            isRecording = false

            val samples = audioBuffer.toFloatArray()
            audioBuffer.clear()

            if (samples.isEmpty()) {
                Log.w(TAG, "No audio samples captured")
                return@withContext null
            }

            val duration = samples.size.toFloat() / SAMPLE_RATE
            Log.d(TAG, "Recording stopped. Duration: ${String.format("%.2f", duration)}s, Samples: ${samples.size}")

            AudioData(
                samples = samples,
                sampleRate = SAMPLE_RATE,
                durationSeconds = duration
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording", e)
            audioRecord?.release()
            audioRecord = null
            isRecording = false
            null
        }
    }

    /**
     * Cancel recording without returning data.
     */
    fun cancelRecording() {
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling recording", e)
        } finally {
            audioRecord = null
            isRecording = false
            audioBuffer.clear()
        }
    }

    companion object {
        private const val TAG = "AudioRecorder"

        // Whisper requires 16kHz mono audio
        const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val CHUNK_SIZE = 1024

        // Audio duration limits
        const val MIN_DURATION_SECONDS = 0.5f
        const val MAX_DURATION_SECONDS = 30f * 60f // 30 minutes
    }
}

/**
 * Container for recorded audio data.
 */
data class AudioData(
    val samples: FloatArray,
    val sampleRate: Int,
    val durationSeconds: Float
) {
    val isTooShort: Boolean
        get() = durationSeconds < AudioRecorder.MIN_DURATION_SECONDS

    val isTooLong: Boolean
        get() = durationSeconds > AudioRecorder.MAX_DURATION_SECONDS

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as AudioData
        return samples.contentEquals(other.samples) &&
                sampleRate == other.sampleRate &&
                durationSeconds == other.durationSeconds
    }

    override fun hashCode(): Int {
        var result = samples.contentHashCode()
        result = 31 * result + sampleRate
        result = 31 * result + durationSeconds.hashCode()
        return result
    }
}
