package com.localwhisper.android.ui

import android.os.Bundle
import android.view.MenuItem
import androidx.appcompat.app.AppCompatActivity
import androidx.preference.ListPreference
import androidx.preference.Preference
import androidx.preference.PreferenceFragmentCompat
import com.localwhisper.android.LocalWhisperApplication
import com.localwhisper.android.R
import com.localwhisper.android.databinding.ActivitySettingsBinding
import com.localwhisper.android.transcription.WhisperModel

class SettingsActivity : AppCompatActivity() {

    private lateinit var binding: ActivitySettingsBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setSupportActionBar(binding.toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = getString(R.string.settings_title)

        if (savedInstanceState == null) {
            supportFragmentManager
                .beginTransaction()
                .replace(R.id.settings_container, SettingsFragment())
                .commit()
        }
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                onBackPressedDispatcher.onBackPressed()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    class SettingsFragment : PreferenceFragmentCompat() {

        private val whisperManager
            get() = (requireActivity().application as LocalWhisperApplication).whisperManager

        override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
            setPreferencesFromResource(R.xml.preferences, rootKey)

            // Model preference
            findPreference<ListPreference>("model")?.apply {
                val models = WhisperModel.values()
                entries = models.map { "${it.displayName} (${it.sizeFormatted})" }.toTypedArray()
                entryValues = models.map { it.name }.toTypedArray()

                setOnPreferenceChangeListener { _, newValue ->
                    val model = WhisperModel.valueOf(newValue as String)
                    summary = "${model.displayName} - ${model.description}"
                    true
                }

                // Set initial summary
                value?.let {
                    try {
                        val model = WhisperModel.valueOf(it)
                        summary = "${model.displayName} - ${model.description}"
                    } catch (e: Exception) {
                        summary = getString(R.string.pref_model_summary)
                    }
                }
            }

            // Language preference
            findPreference<Preference>("language")?.apply {
                setOnPreferenceChangeListener { _, newValue ->
                    summary = "Current: $newValue"
                    true
                }
            }

            // Storage info
            findPreference<Preference>("storage_info")?.apply {
                val totalSize = WhisperModel.values()
                    .filter { whisperManager.isModelDownloaded(it) }
                    .sumOf { whisperManager.getModelSize(it) }

                summary = if (totalSize > 0) {
                    "Downloaded models: ${formatSize(totalSize)}"
                } else {
                    "No models downloaded"
                }
            }

            // Clear models
            findPreference<Preference>("clear_models")?.apply {
                setOnPreferenceClickListener {
                    showClearModelsDialog()
                    true
                }
            }

            // About
            findPreference<Preference>("about")?.apply {
                summary = "Version ${requireContext().packageManager.getPackageInfo(requireContext().packageName, 0).versionName}"
            }
        }

        private fun showClearModelsDialog() {
            androidx.appcompat.app.AlertDialog.Builder(requireContext())
                .setTitle("Clear Downloaded Models")
                .setMessage("This will delete all downloaded Whisper models. You'll need to download them again to use voice input.")
                .setPositiveButton("Clear") { _, _ ->
                    WhisperModel.values().forEach { model ->
                        whisperManager.deleteModel(model)
                    }
                    // Refresh storage info
                    findPreference<Preference>("storage_info")?.summary = "No models downloaded"
                }
                .setNegativeButton("Cancel", null)
                .show()
        }

        private fun formatSize(bytes: Long): String {
            return when {
                bytes >= 1_000_000_000 -> String.format("%.1f GB", bytes / 1_000_000_000f)
                bytes >= 1_000_000 -> String.format("%.0f MB", bytes / 1_000_000f)
                else -> String.format("%.0f KB", bytes / 1_000f)
            }
        }
    }
}
