# LocalWhisper

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
   git clone https://github.com/yourusername/local-whisper.git
   cd local-whisper
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

LocalWhisper requires two permissions:

1. **Microphone**: To capture audio for transcription
2. **Accessibility**: For global keyboard shortcuts and text injection

The app will guide you through granting these permissions on first launch.

## Usage

1. Launch LocalWhisper - it appears in your menu bar as a waveform icon
2. Grant required permissions when prompted
3. Wait for the model to load (first launch may take longer)
4. Press `Cmd+Shift+Space` (or your custom shortcut) to start recording
5. Speak your text
6. Release the shortcut to transcribe and inject text

### Customizing the Shortcut

1. Click the LocalWhisper icon in the menu bar
2. Click on the shortcut recorder
3. Press your desired key combination

## Models

LocalWhisper uses [WhisperKit](https://github.com/argmaxinc/WhisperKit), which provides optimized CoreML models for Apple Silicon. Choose a model based on your needs:

### Model Comparison

| Model | Parameters | Disk Size | Speed Factor* | WER** | Memory | Best For |
|-------|------------|-----------|---------------|-------|--------|----------|
| `tiny` | 39M | ~75MB | ~180x | ~17% | ~1GB | Quick tests |
| `tiny.en` | 39M | ~75MB | ~190x | ~16% | ~1GB | English-only, fastest |
| `base` | 74M | ~140MB | ~111x | ~15% | ~1GB | **Default, good balance** |
| `base.en` | 74M | ~140MB | ~120x | ~14% | ~1GB | English-only dictation |
| `small` | 244M | ~460MB | ~35x | ~13% | ~2GB | Better accuracy |
| `small.en` | 244M | ~460MB | ~40x | ~12% | ~2GB | English, balanced |
| `medium` | 769M | ~1.5GB | ~15x | ~11% | ~4-5GB | High accuracy |
| `medium.en` | 769M | ~1.5GB | ~18x | ~10% | ~4-5GB | English, professional |
| `large-v3` | 1550M | ~3GB | ~8x | ~8% | ~6-7GB | Maximum accuracy |
| `large-v3_turbo` | 809M | ~1.6GB | ~25x | ~9% | ~4GB | **Fast + accurate** |

> \* **Speed Factor**: Seconds of audio processed per second of wall-clock time on M4 chip. Higher is faster.  
> \*\* **WER**: Word Error Rate (lower is better). Based on [earnings22 dataset](https://huggingface.co/datasets/argmaxinc/earnings22-12hours).

### Real-World Latency

How long you'll wait after releasing the record button:

| Audio Length | tiny | base | small | medium | large-v3 | turbo |
|--------------|------|------|-------|--------|----------|-------|
| 5 seconds | 0.03s | 0.05s | 0.14s | 0.33s | 0.63s | 0.20s |
| 15 seconds | 0.08s | 0.14s | 0.43s | 1.00s | 1.88s | 0.60s |
| 30 seconds | 0.17s | 0.27s | 0.86s | 2.00s | 3.75s | 1.20s |
| 60 seconds | 0.33s | 0.54s | 1.71s | 4.00s | 7.50s | 2.40s |

*Measured on M4 Mac mini. M1/M2/M3 will be slightly slower.*

### Which Model Should I Use?

| Your Priority | Recommended Model | Why |
|---------------|-------------------|-----|
| 🚀 **Speed** (instant dictation) | `base.en` or `tiny.en` | Near-instant, good enough accuracy |
| ⚖️ **Balanced** (general use) | `base` or `small.en` | Good accuracy, minimal latency |
| 🎯 **Accuracy** (professional) | `large-v3_turbo` | Best speed/accuracy ratio |
| 🏆 **Maximum quality** | `large-v3` | Lowest error rate, worth the wait |
| 🌍 **Multilingual** | `small` or `large-v3` | Full language support (avoid `.en`) |
| 💾 **Low memory** (8GB Mac) | `tiny` or `base` | Fits comfortably in RAM |

### Changing Models

1. Click the LocalWhisper icon in the menu bar
2. Click ⚙️ Settings (or the gear icon)
3. Go to **Model** tab
4. Select your preferred model

The first time you select a model, it will be downloaded from HuggingFace (~30s to 5min depending on size and connection).

### Why WhisperKit? (vs whisper.cpp)

LocalWhisper uses **WhisperKit** instead of other Whisper implementations like **whisper.cpp**. Here's why:

| Aspect | WhisperKit | whisper.cpp |
|--------|------------|-------------|
| **Apple Silicon optimization** | ✅ Neural Engine via CoreML | ⚠️ Metal/CPU only |
| **Hardware acceleration** | Neural Engine + GPU + CPU | GPU (Metal) + CPU |
| **Swift integration** | Native Swift API | Requires C/FFI bridge |
| **Model format** | CoreML (.mlmodelc) | GGML (.bin) |
| **Quantization** | CoreML optimized | 4-bit, 8-bit options |
| **Maintenance** | Active (Argmax) | Active (ggerganov) |

**Bottom line**: On Apple Silicon, WhisperKit leverages the dedicated Neural Engine that whisper.cpp cannot access, resulting in better performance for most use cases. whisper.cpp may have advantages for extreme memory constraints (4-bit quantization) or Intel Macs.

### Benchmarking Your Setup

Run the reference benchmark script to see model comparisons:

```bash
swift benchmark_models.swift
```

For live benchmarking with your hardware, use the [WhisperKit CLI](https://github.com/argmaxinc/WhisperKit):

```bash
# Clone WhisperKit
git clone https://github.com/argmaxinc/WhisperKit
cd WhisperKit

# Benchmark a specific model
swift run whisperkit-cli transcribe \
  --audio-path /path/to/audio.wav \
  --model openai_whisper-base \
  --verbose
```

## Architecture

```
LocalWhisper/
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

LocalWhisper is designed with privacy in mind:

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
