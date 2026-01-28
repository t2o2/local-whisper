package com.localwhisper.android.transcription

import android.content.Context
import android.util.Log
import com.localwhisper.android.audio.AudioData
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

/**
 * Manages Whisper model loading and transcription.
 * Uses whisper.cpp via JNI for efficient on-device transcription.
 */
class WhisperManager(private val context: Context) {

    private var whisperContext: Long = 0
    private var isModelLoaded = false

    private val _modelState = MutableStateFlow<ModelState>(ModelState.NotLoaded)
    val modelState: StateFlow<ModelState> = _modelState.asStateFlow()

    private val _transcriptionState = MutableStateFlow<TranscriptionState>(TranscriptionState.Idle)
    val transcriptionState: StateFlow<TranscriptionState> = _transcriptionState.asStateFlow()

    private val modelsDir: File
        get() = File(context.filesDir, "models").also { it.mkdirs() }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    init {
        try {
            System.loadLibrary("whisper_jni")
            Log.d(TAG, "Whisper native library loaded")
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "Failed to load whisper native library", e)
        }
    }

    /**
     * Load or download a Whisper model.
     */
    suspend fun loadModel(model: WhisperModel, onProgress: (Float) -> Unit = {}): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                _modelState.value = ModelState.Loading(0f)

                val modelFile = File(modelsDir, model.fileName)

                // Download if not exists
                if (!modelFile.exists()) {
                    Log.d(TAG, "Downloading model: ${model.displayName}")
                    val success = downloadModel(model, modelFile, onProgress)
                    if (!success) {
                        _modelState.value = ModelState.Error("Failed to download model")
                        return@withContext false
                    }
                }

                // Load the model
                Log.d(TAG, "Loading model from: ${modelFile.absolutePath}")
                _modelState.value = ModelState.Loading(0.9f)

                whisperContext = whisperInit(modelFile.absolutePath)

                if (whisperContext == 0L) {
                    _modelState.value = ModelState.Error("Failed to initialize Whisper")
                    return@withContext false
                }

                isModelLoaded = true
                _modelState.value = ModelState.Loaded(model)
                Log.d(TAG, "Model loaded successfully: ${model.displayName}")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Error loading model", e)
                _modelState.value = ModelState.Error(e.message ?: "Unknown error")
                false
            }
        }
    }

    private suspend fun downloadModel(
        model: WhisperModel,
        targetFile: File,
        onProgress: (Float) -> Unit
    ): Boolean = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url(model.downloadUrl)
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    Log.e(TAG, "Download failed: ${response.code}")
                    return@withContext false
                }

                val body = response.body ?: return@withContext false
                val contentLength = body.contentLength()
                var bytesRead = 0L

                FileOutputStream(targetFile).use { output ->
                    body.byteStream().use { input ->
                        val buffer = ByteArray(8192)
                        var read: Int
                        while (input.read(buffer).also { read = it } != -1) {
                            output.write(buffer, 0, read)
                            bytesRead += read
                            if (contentLength > 0) {
                                val progress = bytesRead.toFloat() / contentLength * 0.8f
                                onProgress(progress)
                                _modelState.value = ModelState.Loading(progress)
                            }
                        }
                    }
                }

                Log.d(TAG, "Model downloaded: ${targetFile.length()} bytes")
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Download error", e)
            targetFile.delete()
            false
        }
    }

    /**
     * Transcribe audio data to text.
     */
    suspend fun transcribe(audioData: AudioData, language: String = "en"): TranscriptionResult {
        return withContext(Dispatchers.IO) {
            if (!isModelLoaded || whisperContext == 0L) {
                return@withContext TranscriptionResult.Error("Model not loaded")
            }

            if (audioData.isTooShort) {
                return@withContext TranscriptionResult.Error("Audio too short (min 0.5s)")
            }

            if (audioData.isTooLong) {
                return@withContext TranscriptionResult.Error("Audio too long (max 30 min)")
            }

            try {
                _transcriptionState.value = TranscriptionState.Transcribing
                Log.d(TAG, "Starting transcription: ${audioData.durationSeconds}s of audio")

                val startTime = System.currentTimeMillis()

                val text = whisperTranscribe(
                    whisperContext,
                    audioData.samples,
                    language
                )

                val elapsed = System.currentTimeMillis() - startTime
                val speedFactor = audioData.durationSeconds / (elapsed / 1000f)

                Log.d(TAG, "Transcription complete in ${elapsed}ms (${String.format("%.1f", speedFactor)}x realtime)")

                _transcriptionState.value = TranscriptionState.Idle

                if (text.isNullOrBlank()) {
                    TranscriptionResult.Error("No speech detected")
                } else {
                    TranscriptionResult.Success(text.trim())
                }
            } catch (e: Exception) {
                Log.e(TAG, "Transcription error", e)
                _transcriptionState.value = TranscriptionState.Idle
                TranscriptionResult.Error(e.message ?: "Transcription failed")
            }
        }
    }

    /**
     * Release resources.
     */
    fun release() {
        if (whisperContext != 0L) {
            whisperFree(whisperContext)
            whisperContext = 0
            isModelLoaded = false
        }
    }

    /**
     * Check if a model file exists locally.
     */
    fun isModelDownloaded(model: WhisperModel): Boolean {
        return File(modelsDir, model.fileName).exists()
    }

    /**
     * Delete a downloaded model.
     */
    fun deleteModel(model: WhisperModel): Boolean {
        val file = File(modelsDir, model.fileName)
        return if (file.exists()) file.delete() else true
    }

    /**
     * Get size of downloaded model.
     */
    fun getModelSize(model: WhisperModel): Long {
        val file = File(modelsDir, model.fileName)
        return if (file.exists()) file.length() else 0
    }

    // Native methods (implemented in whisper.cpp)
    private external fun whisperInit(modelPath: String): Long
    private external fun whisperTranscribe(context: Long, samples: FloatArray, language: String): String?
    private external fun whisperFree(context: Long)

    companion object {
        private const val TAG = "WhisperManager"
    }
}

/**
 * Available Whisper models.
 */
enum class WhisperModel(
    val displayName: String,
    val fileName: String,
    val downloadUrl: String,
    val sizeBytes: Long,
    val description: String
) {
    TINY(
        displayName = "Tiny",
        fileName = "ggml-tiny.bin",
        downloadUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
        sizeBytes = 75_000_000,
        description = "Fastest, least accurate (~75MB)"
    ),
    BASE(
        displayName = "Base",
        fileName = "ggml-base.bin",
        downloadUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
        sizeBytes = 142_000_000,
        description = "Good balance of speed/accuracy (~142MB)"
    ),
    SMALL(
        displayName = "Small",
        fileName = "ggml-small.bin",
        downloadUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
        sizeBytes = 466_000_000,
        description = "Better accuracy, slower (~466MB)"
    ),
    MEDIUM(
        displayName = "Medium",
        fileName = "ggml-medium.bin",
        downloadUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin",
        sizeBytes = 1_500_000_000,
        description = "High accuracy, slow (~1.5GB)"
    );

    val sizeFormatted: String
        get() = when {
            sizeBytes >= 1_000_000_000 -> String.format("%.1f GB", sizeBytes / 1_000_000_000f)
            sizeBytes >= 1_000_000 -> String.format("%.0f MB", sizeBytes / 1_000_000f)
            else -> String.format("%.0f KB", sizeBytes / 1_000f)
        }
}

/**
 * Model loading state.
 */
sealed class ModelState {
    object NotLoaded : ModelState()
    data class Loading(val progress: Float) : ModelState()
    data class Loaded(val model: WhisperModel) : ModelState()
    data class Error(val message: String) : ModelState()
}

/**
 * Transcription state.
 */
sealed class TranscriptionState {
    object Idle : TranscriptionState()
    object Transcribing : TranscriptionState()
}

/**
 * Transcription result.
 */
sealed class TranscriptionResult {
    data class Success(val text: String) : TranscriptionResult()
    data class Error(val message: String) : TranscriptionResult()
}
