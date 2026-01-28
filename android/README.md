# LocalWhisper for Android

An Android voice-to-text keyboard powered by OpenAI's Whisper model running locally on your device.

## Features

- **Local Processing**: All transcription happens on-device using whisper.cpp - no internet required after model download
- **Voice Keyboard**: Input Method Editor (IME) that works in any app
- **Multiple Models**: Choose from Tiny (~75MB) to Medium (~1.5GB) based on your accuracy/speed needs
- **Hold-to-Record**: Simple press-and-hold interface for recording
- **Privacy First**: Your voice data never leaves your device

## Requirements

- Android 8.0 (API 26) or higher
- ARM64, ARMv7, or x86_64 device
- ~150MB - 1.5GB storage for models

## Building

### Prerequisites

- Android Studio Hedgehog (2023.1.1) or newer
- Android SDK 34
- NDK 25.1.8937393 or newer
- CMake 3.22.1 or newer

### Build Steps

1. Open the `android` directory in Android Studio
2. Sync Gradle files
3. Build the project (Build → Make Project)
4. Run on device or emulator

```bash
# Or build from command line
cd android
./gradlew assembleDebug
```

## Usage

1. **Download a Model**: Open the app and tap "Download Model" to select and download a Whisper model
2. **Grant Permissions**: Allow microphone access when prompted
3. **Enable Keyboard**: Go to Settings → Language & Input → On-screen keyboard and enable "LocalWhisper Voice"
4. **Select Keyboard**: In any text field, switch to LocalWhisper Voice using the keyboard selector
5. **Record**: Hold the microphone button, speak, then release to transcribe

## Architecture

```
android/
├── app/src/main/
│   ├── java/com/localwhisper/android/
│   │   ├── LocalWhisperApplication.kt  # App initialization
│   │   ├── audio/
│   │   │   └── AudioRecorder.kt        # 16kHz mono audio capture
│   │   ├── transcription/
│   │   │   └── WhisperManager.kt       # Model loading & transcription
│   │   ├── service/
│   │   │   ├── WhisperInputMethodService.kt  # Voice keyboard IME
│   │   │   └── TranscriptionService.kt       # Background service
│   │   └── ui/
│   │       ├── MainActivity.kt         # Setup wizard
│   │       └── SettingsActivity.kt     # App settings
│   ├── cpp/
│   │   ├── CMakeLists.txt              # Native build config
│   │   └── whisper_jni.cpp             # JNI bridge to whisper.cpp
│   └── res/
│       ├── layout/                     # UI layouts
│       ├── xml/                        # IME config, preferences
│       └── values/                     # Strings, colors, themes
└── build.gradle.kts
```

## Model Options

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| Tiny | ~75MB | Fastest | Basic | Quick notes, simple phrases |
| Base | ~142MB | Fast | Good | General use (recommended) |
| Small | ~466MB | Moderate | Better | Longer dictation |
| Medium | ~1.5GB | Slow | High | Professional transcription |

## Troubleshooting

### Keyboard not appearing
- Ensure you've enabled LocalWhisper Voice in keyboard settings
- Try restarting the app or your device

### Recording fails
- Check that microphone permission is granted
- Close other apps that may be using the microphone

### Transcription is slow
- Try a smaller model (Tiny or Base)
- Ensure your device isn't in battery saver mode

### No speech detected
- Speak clearly and at a normal volume
- Ensure you're holding the button for at least 0.5 seconds

## License

Same license as the parent LocalWhisper project.
