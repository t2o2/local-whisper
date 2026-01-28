# LocalWhisper

<p align="center">
  <strong>Local voice-to-text for macOS</strong><br>
  100% offline • Apple Silicon optimized • Menu bar app
</p>

<p align="center">
  <a href="https://github.com/t2o2/local-whisper/actions/workflows/ci.yml"><img src="https://github.com/t2o2/local-whisper/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI"></a>
  <a href="https://github.com/t2o2/local-whisper/releases/latest"><img src="https://img.shields.io/github/v/release/t2o2/local-whisper" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
</p>

---

A macOS menu bar app for local speech-to-text powered by [WhisperKit](https://github.com/argmaxinc/WhisperKit). Press a hotkey, speak, and text appears in any app — no internet required.

## Quick Start

### Install (Recommended)

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/t2o2/local-whisper/releases/latest)
2. Open the DMG and drag **LocalWhisper** to your Applications folder
3. Open LocalWhisper from Applications
4. Grant **Microphone** and **Accessibility** permissions when prompted

> **Note**: On first launch, you may see "unidentified developer" warning. Right-click the app and select "Open" to bypass this.

### Install from Source

```bash
git clone https://github.com/t2o2/local-whisper.git
cd local-whisper
swift build && swift run
```

### Use

1. Grant **Microphone** and **Accessibility** permissions when prompted
2. **Hold** your shortcut key (default: `Ctrl+Shift+Space`) to start recording
3. Speak while holding the key
4. **Release** to stop recording and transcribe

Text is automatically typed into your focused app.

## Features

- 🎤 **Global Hotkey** — Hold to record, release to transcribe (default: `Ctrl+Shift+Space`)
- 🔒 **100% Offline** — All processing on-device, no data leaves your Mac
- ⚡ **Fast** — CoreML + Neural Engine acceleration on Apple Silicon
- 📝 **Auto-inject** — Transcribed text typed directly into focused field
- 📖 **Custom Dictionary** — Add words/names for accurate transcription of technical terms, proper nouns, etc.

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- 8GB RAM minimum (16GB+ for large models)

## Configuration

Click the menu bar icon to:
- Change keyboard shortcut
- Select transcription model (tiny → large-v3)
- Add custom vocabulary (product names, technical terms, proper nouns)
- Adjust settings

### Custom Dictionary

Add words you want transcribed correctly in Settings → Custom Vocabulary. This helps the model recognize:
- Product names (e.g., "WhisperKit", "CoreML")
- Technical terms (e.g., "Kubernetes", "PostgreSQL")  
- Proper nouns (e.g., names of people, places, companies)

> **Tip**: Works best with larger models (small, medium, large-v3). The dictionary provides spelling hints, not instructions.

<p align="center">
  <img src="docs/images/settings.png" alt="LocalWhisper Settings" width="600">
</p>

## Documentation

- [Model Guide](docs/models.md) — Model comparison, benchmarks, recommendations
- [Architecture](docs/architecture.md) — Project structure, development guide

## Privacy

All transcription happens locally. No audio is sent over the network. No analytics or telemetry.

## License

MIT

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) — Swift Whisper with CoreML
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Global hotkeys
- [OpenAI Whisper](https://github.com/openai/whisper) — Original model
