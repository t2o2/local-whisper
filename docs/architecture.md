# Architecture

## Project Structure

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

## Core Components

### AppState (`App/AppState.swift`)
Global state container that holds all services and application state. Uses `@MainActor` for UI safety.

### TranscriptionCoordinator (`Coordinators/`)
Orchestrates the full workflow: hotkey → record → transcribe → inject.

### Services

| Service | Purpose |
|---------|---------|
| `AudioCaptureService` | AVAudioEngine-based 16kHz mono recording |
| `TranscriptionService` | WhisperKit wrapper for model loading and transcription |
| `TextInjectionService` | AXUIElement API + clipboard fallback for text injection |
| `PermissionsService` | macOS permission handling (mic, accessibility) |

## Key Patterns

- **Actor isolation**: Services use Swift actors for thread safety
- **@MainActor**: UI-related code (AppState, Coordinator, Views)
- **Dependency injection**: Services configured via AppState

## Dependencies

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) (0.9.0+) - Local Whisper transcription with CoreML
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (2.0.0+) - Global hotkey handling

## Development

### Build Commands

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run
swift run

# Open in Xcode
open Package.swift
```

### Adding a New Setting

1. Add `@AppStorage` property to `AppState`
2. Add UI in `SettingsView.swift`
3. Use in relevant service

### Changing the Default Shortcut

Edit `AppDelegate.setupGlobalShortcut()` - default is `Cmd+Shift+Space`

### Debugging Transcription

Enable verbose logging in `TranscriptionService`:

```swift
let config = WhisperKitConfig(..., verbose: true)
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Hotkey not working | Check Accessibility permission in System Settings |
| No audio captured | Check Microphone permission |
| Text not injected | Some apps need clipboard fallback enabled |
| Model load fails | Check network for first download, then cached locally |

### Text Injection Notes

- AXUIElement works for native macOS apps
- Electron apps (VS Code, Slack) may need clipboard fallback
- Test in various apps: TextEdit, Safari, VS Code, Terminal
