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

### Install

```bash
git clone https://github.com/t2o2/local-whisper.git
cd local-whisper
swift build && swift run
```

### Use

1. Grant **Microphone** and **Accessibility** permissions when prompted
2. Press `Cmd+Shift+Space` to record
3. Speak, then release to transcribe

Text is automatically typed into your focused app.

## Features

- 🎤 **Global Hotkey** — Record from anywhere with `Cmd+Shift+Space`
- 🔒 **100% Offline** — All processing on-device, no data leaves your Mac
- ⚡ **Fast** — CoreML + Neural Engine acceleration on Apple Silicon
- 📝 **Auto-inject** — Transcribed text typed directly into focused field

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- 8GB RAM minimum (16GB+ for large models)

## Configuration

Click the menu bar icon to:
- Change keyboard shortcut
- Select transcription model (tiny → large-v3)
- Adjust settings

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
