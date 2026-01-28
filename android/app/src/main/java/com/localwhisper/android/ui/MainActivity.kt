package com.localwhisper.android.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.localwhisper.android.LocalWhisperApplication
import com.localwhisper.android.R
import com.localwhisper.android.databinding.ActivityMainBinding
import com.localwhisper.android.transcription.ModelState
import com.localwhisper.android.transcription.WhisperModel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    private val whisperManager
        get() = (application as LocalWhisperApplication).whisperManager

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        updatePermissionStatus()
        if (!isGranted) {
            Toast.makeText(this, "Microphone permission is required", Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupUI()
        observeModelState()
    }

    override fun onResume() {
        super.onResume()
        updateSetupStatus()
    }

    private fun setupUI() {
        // Settings button
        binding.settingsButton.setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }

        // Step 1: Download model
        binding.step1Button.setOnClickListener {
            showModelSelectionDialog()
        }

        // Step 2: Grant permission
        binding.step2Button.setOnClickListener {
            requestMicrophonePermission()
        }

        // Step 3: Enable keyboard
        binding.step3Button.setOnClickListener {
            startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
        }

        // Step 4: Select keyboard
        binding.step4Button.setOnClickListener {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showInputMethodPicker()
        }

        // Try it text field
        binding.tryItEditText.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                binding.tryItHint.visibility = View.GONE
            }
        }
    }

    private fun observeModelState() {
        lifecycleScope.launch {
            whisperManager.modelState.collectLatest { state ->
                updateModelUI(state)
            }
        }
    }

    private fun updateModelUI(state: ModelState) {
        when (state) {
            is ModelState.NotLoaded -> {
                binding.step1Status.text = "Not downloaded"
                binding.step1Status.setTextColor(getColor(R.color.text_secondary))
                binding.step1Button.text = getString(R.string.download_model)
                binding.step1Button.isEnabled = true
                binding.step1Progress.visibility = View.GONE
            }
            is ModelState.Loading -> {
                val percent = (state.progress * 100).toInt()
                binding.step1Status.text = "Downloading... $percent%"
                binding.step1Status.setTextColor(getColor(R.color.primary))
                binding.step1Button.isEnabled = false
                binding.step1Progress.visibility = View.VISIBLE
                binding.step1Progress.progress = percent
            }
            is ModelState.Loaded -> {
                binding.step1Status.text = "Ready: ${state.model.displayName}"
                binding.step1Status.setTextColor(getColor(R.color.success))
                binding.step1Button.text = "Change Model"
                binding.step1Button.isEnabled = true
                binding.step1Progress.visibility = View.GONE
                binding.step1Check.visibility = View.VISIBLE
            }
            is ModelState.Error -> {
                binding.step1Status.text = "Error: ${state.message}"
                binding.step1Status.setTextColor(getColor(R.color.error))
                binding.step1Button.text = getString(R.string.download_model)
                binding.step1Button.isEnabled = true
                binding.step1Progress.visibility = View.GONE
            }
        }
    }

    private fun updateSetupStatus() {
        // Update permission status
        updatePermissionStatus()

        // Update keyboard enabled status
        val isKeyboardEnabled = isKeyboardEnabled()
        if (isKeyboardEnabled) {
            binding.step3Status.text = "Enabled"
            binding.step3Status.setTextColor(getColor(R.color.success))
            binding.step3Check.visibility = View.VISIBLE
        } else {
            binding.step3Status.text = "Not enabled"
            binding.step3Status.setTextColor(getColor(R.color.text_secondary))
            binding.step3Check.visibility = View.GONE
        }

        // Step 4 is always available once keyboard is enabled
        binding.step4Card.alpha = if (isKeyboardEnabled) 1f else 0.5f
        binding.step4Button.isEnabled = isKeyboardEnabled
    }

    private fun updatePermissionStatus() {
        val hasPermission = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (hasPermission) {
            binding.step2Status.text = "Granted"
            binding.step2Status.setTextColor(getColor(R.color.success))
            binding.step2Check.visibility = View.VISIBLE
            binding.step2Button.text = "Granted"
            binding.step2Button.isEnabled = false
        } else {
            binding.step2Status.text = "Not granted"
            binding.step2Status.setTextColor(getColor(R.color.text_secondary))
            binding.step2Check.visibility = View.GONE
            binding.step2Button.text = getString(R.string.grant_permission)
            binding.step2Button.isEnabled = true
        }
    }

    private fun requestMicrophonePermission() {
        when {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED -> {
                // Already granted
                updatePermissionStatus()
            }
            shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO) -> {
                AlertDialog.Builder(this)
                    .setTitle("Microphone Permission")
                    .setMessage("LocalWhisper needs microphone access to transcribe your voice into text.")
                    .setPositiveButton("Grant") { _, _ ->
                        requestPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                    }
                    .setNegativeButton("Cancel", null)
                    .show()
            }
            else -> {
                requestPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        }
    }

    private fun showModelSelectionDialog() {
        val models = WhisperModel.values()
        val modelNames = models.map { "${it.displayName} (${it.sizeFormatted})" }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle(getString(R.string.select_model))
            .setItems(modelNames) { _, which ->
                val selectedModel = models[which]
                downloadModel(selectedModel)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun downloadModel(model: WhisperModel) {
        lifecycleScope.launch {
            val success = whisperManager.loadModel(model) { progress ->
                // Progress updates handled by state flow
            }

            if (!success) {
                Toast.makeText(
                    this@MainActivity,
                    "Failed to load model",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    private fun isKeyboardEnabled(): Boolean {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        val enabledInputMethods = imm.enabledInputMethodList
        return enabledInputMethods.any {
            it.packageName == packageName
        }
    }
}
