# LocalWispr

A local voice-to-text macOS application powered by WhisperKit. Transcribe speech directly into any application using a global keyboard shortcut — 100% offline, no data ever leaves your device.

## Features

- 🎤 **Global Hotkey**: Press `Cmd+Shift+Space` (customizable) to start recording from anywhere
- 🔒 **100% Offline**: Uses WhisperKit with local Whisper models - no internet required
- ⚡ **Fast**: Optimized for Apple Silicon with CoreML acceleration
- 📝 **Direct Text Injection**: Transcribed text is automatically typed into the focused text field
- 🎯 **Menu Bar App**: Runs quietly in your menu bar, no dock icon

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3/M4)
- At least 8GB RAM (16GB+ recommended for large-v3 model)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/local-wispr.git
   cd local-wispr
   ```

2. Build and run:
   ```bash
   swift build
   swift run
   ```

   Or open in Xcode:
   ```bash
   open Package.swift
   ```

### Permissions Required

LocalWispr requires two permissions:

1. **Microphone**: To capture audio for transcription
2. **Accessibility**: For global keyboard shortcuts and text injection

The app will guide you through granting these permissions on first launch.

## Usage

1. Launch LocalWispr - it appears in your menu bar as a waveform icon
2. Grant required permissions when prompted
3. Wait for the model to load (first launch may take longer)
4. Press `Cmd+Shift+Space` (or your custom shortcut) to start recording
5. Speak your text
6. Release the shortcut to transcribe and inject text

### Customizing the Shortcut

1. Click the LocalWispr icon in the menu bar
2. Click on the shortcut recorder
3. Press your desired key combination

## Models

LocalWispr supports multiple Whisper model sizes:

| Model | Size | Memory | Best For |
|-------|------|--------|----------|
| tiny | ~75MB | ~1GB | Quick tests, low resources |
| base | ~140MB | ~1GB | Basic transcription |
| small | ~460MB | ~2GB | Balanced performance |
| medium | ~1.5GB | ~5GB | Good accuracy |
| **large-v3** | ~3GB | ~6GB | Best accuracy (recommended for M4) |

Change the model in Settings > Model.

## Architecture

```
LocalWispr/
├── App/                 # App entry point, delegate, global state
├── UI/                  # SwiftUI views (menu bar, settings)
├── Services/            # Core services
│   ├── AudioCaptureService    # AVAudioEngine-based recording
│   ├── TranscriptionService   # WhisperKit integration
│   ├── TextInjectionService   # AXUIElement + clipboard fallback
│   └── PermissionsService     # macOS permission handling
├── Coordinators/        # Workflow orchestration
├── Models/              # Data models
└── Resources/           # Assets, Info.plist
```

## Privacy

LocalWispr is designed with privacy in mind:

- ✅ All transcription happens locally using WhisperKit
- ✅ No audio is ever sent over the network
- ✅ No analytics or telemetry
- ✅ Models are downloaded once and cached locally

## Development

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run
swift run
```

### Dependencies

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - Swift-native Whisper implementation
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global keyboard shortcuts

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) - The original speech recognition model
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - Swift implementation with CoreML support
- [Sindre Sorhus](https://github.com/sindresorhus) - KeyboardShortcuts library
