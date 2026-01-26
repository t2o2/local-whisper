# CLAUDE.md - LocalWispr Development Guidelines

## Project Overview

LocalWispr is a macOS menu bar application for local voice-to-text transcription using WhisperKit. It captures audio via global hotkeys and injects transcribed text into any focused application.

## Build Commands

```bash
# Build the project
swift build

# Run the app
swift run

# Build for release
swift build -c release

# Open in Xcode
open Package.swift
```

## Architecture

### Core Components

1. **AppState** (`App/AppState.swift`) - Global state container, holds all services
2. **TranscriptionCoordinator** (`Coordinators/`) - Orchestrates the workflow: hotkey → record → transcribe → inject
3. **Services** (`Services/`):
   - `AudioCaptureService` - AVAudioEngine-based 16kHz mono recording
   - `TranscriptionService` - WhisperKit wrapper
   - `TextInjectionService` - AXUIElement API + clipboard fallback
   - `PermissionsService` - macOS permission handling

### Key Patterns

- **Actor isolation**: Services use Swift actors for thread safety
- **@MainActor**: UI-related code (AppState, Coordinator, Views)
- **Dependency injection**: Services configured via AppState

## Key Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM dependencies (WhisperKit, KeyboardShortcuts) |
| `App/AppDelegate.swift` | Menu bar setup, global shortcut registration |
| `Services/AudioCaptureService.swift` | Microphone recording in Whisper format |
| `Services/TranscriptionService.swift` | WhisperKit model loading and transcription |
| `Services/TextInjectionService.swift` | Inject text via Accessibility API |

## Common Tasks

### Adding a new setting
1. Add `@AppStorage` property to `AppState`
2. Add UI in `SettingsView.swift`
3. Use in relevant service

### Changing the default shortcut
Edit `AppDelegate.setupGlobalShortcut()` - default is `Cmd+Shift+Space`

### Debugging transcription
Enable verbose logging in `TranscriptionService`:
```swift
let config = WhisperKitConfig(..., verbose: true)
```

## Dependencies

- **WhisperKit** (0.9.0+): Local Whisper transcription with CoreML
- **KeyboardShortcuts** (2.0.0+): Global hotkey handling

## Testing Notes

- Test text injection in various apps: TextEdit, Safari, VS Code, Terminal
- AXUIElement works for native apps; clipboard fallback for Electron apps
- Model loading takes ~30s for large-v3 on first run

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Hotkey not working | Check Accessibility permission in System Settings |
| No audio captured | Check Microphone permission |
| Text not injected | Some apps need clipboard fallback enabled |
| Model load fails | Check network for first download, then cached locally |
