package com.localwhisper.android.service

import android.Manifest
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.localwhisper.android.LocalWhisperApplication
import com.localwhisper.android.R
import com.localwhisper.android.audio.AudioRecorder
import com.localwhisper.android.transcription.ModelState
import com.localwhisper.android.transcription.TranscriptionResult
import com.localwhisper.android.transcription.TranscriptionState
import com.localwhisper.android.transcription.WhisperModel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collectLatest

/**
 * Input Method Service that provides voice-to-text input using Whisper.
 * Users can hold the microphone button to record, release to transcribe.
 */
class WhisperInputMethodService : InputMethodService() {

    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private val audioRecorder = AudioRecorder()
    private var recordingJob: Job? = null

    // UI elements
    private var keyboardView: View? = null
    private var micButton: ImageButton? = null
    private var statusText: TextView? = null
    private var progressBar: ProgressBar? = null
    private var backspaceButton: ImageButton? = null
    private var spaceButton: View? = null
    private var enterButton: ImageButton? = null

    private val whisperManager: com.localwhisper.android.transcription.WhisperManager
        get() = (application as LocalWhisperApplication).whisperManager

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "WhisperInputMethodService created")

        // Observe model state
        serviceScope.launch {
            whisperManager.modelState.collectLatest { state ->
                updateModelStateUI(state)
            }
        }

        // Observe transcription state
        serviceScope.launch {
            whisperManager.transcriptionState.collectLatest { state ->
                updateTranscriptionStateUI(state)
            }
        }
    }

    override fun onCreateInputView(): View {
        keyboardView = LayoutInflater.from(this)
            .inflate(R.layout.keyboard_view, null)

        setupViews()
        setupListeners()

        return keyboardView!!
    }

    private fun setupViews() {
        keyboardView?.let { view ->
            micButton = view.findViewById(R.id.mic_button)
            statusText = view.findViewById(R.id.status_text)
            progressBar = view.findViewById(R.id.progress_bar)
            backspaceButton = view.findViewById(R.id.backspace_button)
            spaceButton = view.findViewById(R.id.space_button)
            enterButton = view.findViewById(R.id.enter_button)
        }

        // Initial state
        updateModelStateUI(whisperManager.modelState.value)
    }

    private fun setupListeners() {
        // Microphone button - hold to record
        micButton?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startRecording()
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    stopRecordingAndTranscribe()
                    true
                }
                else -> false
            }
        }

        // Backspace button
        backspaceButton?.setOnClickListener {
            currentInputConnection?.deleteSurroundingText(1, 0)
        }

        backspaceButton?.setOnLongClickListener {
            // Delete word on long press
            val textBefore = currentInputConnection?.getTextBeforeCursor(50, 0)?.toString() ?: ""
            val lastSpace = textBefore.trimEnd().lastIndexOf(' ')
            val deleteCount = if (lastSpace >= 0) textBefore.length - lastSpace else textBefore.length
            currentInputConnection?.deleteSurroundingText(deleteCount, 0)
            true
        }

        // Space button
        spaceButton?.setOnClickListener {
            currentInputConnection?.commitText(" ", 1)
        }

        // Enter button
        enterButton?.setOnClickListener {
            val editorInfo = currentInputEditorInfo
            if (editorInfo != null) {
                val action = editorInfo.imeOptions and EditorInfo.IME_MASK_ACTION
                if (action != EditorInfo.IME_ACTION_NONE) {
                    currentInputConnection?.performEditorAction(action)
                } else {
                    currentInputConnection?.commitText("\n", 1)
                }
            } else {
                currentInputConnection?.commitText("\n", 1)
            }
        }
    }

    private fun startRecording() {
        // Check permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            statusText?.text = "Microphone permission required"
            return
        }

        // Check model
        if (whisperManager.modelState.value !is ModelState.Loaded) {
            statusText?.text = "Model not loaded - open app to setup"
            return
        }

        vibrate()
        statusText?.text = "Recording..."
        micButton?.setImageResource(R.drawable.ic_mic_active)

        recordingJob = serviceScope.launch {
            val started = audioRecorder.startRecording()
            if (!started) {
                statusText?.text = "Failed to start recording"
                return@launch
            }

            // Continuously read audio while recording
            while (isActive && audioRecorder.isCurrentlyRecording) {
                audioRecorder.readAudioChunk()
                delay(50) // Small delay between reads
            }
        }
    }

    private fun stopRecordingAndTranscribe() {
        recordingJob?.cancel()
        recordingJob = null

        if (!audioRecorder.isCurrentlyRecording) {
            return
        }

        vibrate()
        micButton?.setImageResource(R.drawable.ic_mic)

        serviceScope.launch {
            statusText?.text = "Transcribing..."
            progressBar?.visibility = View.VISIBLE

            val audioData = audioRecorder.stopRecording()

            if (audioData == null) {
                statusText?.text = "No audio captured"
                progressBar?.visibility = View.GONE
                return@launch
            }

            if (audioData.isTooShort) {
                statusText?.text = "Recording too short"
                progressBar?.visibility = View.GONE
                return@launch
            }

            when (val result = whisperManager.transcribe(audioData)) {
                is TranscriptionResult.Success -> {
                    // Commit transcribed text to the input
                    currentInputConnection?.commitText(result.text, 1)
                    statusText?.text = "Hold mic to speak"
                }
                is TranscriptionResult.Error -> {
                    statusText?.text = result.message
                }
            }

            progressBar?.visibility = View.GONE
        }
    }

    private fun updateModelStateUI(state: ModelState) {
        when (state) {
            is ModelState.NotLoaded -> {
                statusText?.text = "Open app to download model"
                micButton?.isEnabled = false
            }
            is ModelState.Loading -> {
                val percent = (state.progress * 100).toInt()
                statusText?.text = "Loading model... $percent%"
                micButton?.isEnabled = false
            }
            is ModelState.Loaded -> {
                statusText?.text = "Hold mic to speak"
                micButton?.isEnabled = true
            }
            is ModelState.Error -> {
                statusText?.text = "Error: ${state.message}"
                micButton?.isEnabled = false
            }
        }
    }

    private fun updateTranscriptionStateUI(state: TranscriptionState) {
        when (state) {
            is TranscriptionState.Idle -> {
                progressBar?.visibility = View.GONE
            }
            is TranscriptionState.Transcribing -> {
                progressBar?.visibility = View.VISIBLE
            }
        }
    }

    private fun vibrate() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(50)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        audioRecorder.cancelRecording()
        Log.d(TAG, "WhisperInputMethodService destroyed")
    }

    companion object {
        private const val TAG = "WhisperIME"
    }
}
