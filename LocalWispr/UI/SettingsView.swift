import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .environmentObject(appState)
            
            ModelSettingsView()
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }
                .environmentObject(appState)
            
            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .environmentObject(appState)
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Recording shortcut:", name: .toggleRecording)
            }
            
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Use clipboard fallback for text injection", isOn: $appState.useClipboardFallback)
            }
            
            Section("Language") {
                Picker("Transcription language:", selection: $appState.language) {
                    Text("English").tag("en")
                    Text("Auto-detect").tag("")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Chinese").tag("zh")
                    Text("Japanese").tag("ja")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Model Settings
struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isReloading = false
    
    private let models = [
        ("tiny", "Tiny (~75MB) - Fastest, least accurate"),
        ("base", "Base (~140MB) - Fast, basic accuracy"),
        ("small", "Small (~460MB) - Balanced"),
        ("medium", "Medium (~1.5GB) - Good accuracy"),
        ("large-v3", "Large v3 (~3GB) - Best accuracy")
    ]
    
    var body: some View {
        Form {
            Section("Whisper Model") {
                Picker("Model:", selection: $appState.selectedModel) {
                    ForEach(models, id: \.0) { model in
                        Text(model.1).tag(model.0)
                    }
                }
                
                HStack {
                    if appState.isModelLoaded {
                        Label("Model loaded", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if appState.modelLoadProgress > 0 {
                        ProgressView(value: appState.modelLoadProgress)
                            .frame(width: 100)
                        Text("Loading...")
                    } else {
                        Label("Model not loaded", systemImage: "xmark.circle")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Reload Model") {
                        reloadModel()
                    }
                    .disabled(isReloading)
                }
            }
            
            Section {
                Text("Larger models are more accurate but slower and use more memory. The large-v3 model is recommended for M4 Macs with 24GB RAM.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func reloadModel() {
        isReloading = true
        Task {
            await appState.transcriptionService.unloadModel()
            await appState.transcriptionService.loadModel(modelName: appState.selectedModel)
            await MainActor.run {
                isReloading = false
            }
        }
    }
}

// MARK: - Permissions Settings
struct PermissionsSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section("Required Permissions") {
                HStack {
                    Image(systemName: "mic.fill")
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("Microphone")
                            .font(.headline)
                        Text("Required to capture audio for transcription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if appState.permissionsService.microphoneGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Open Settings") {
                            appState.permissionsService.openMicrophoneSettings()
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "accessibility")
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("Accessibility")
                            .font(.headline)
                        Text("Required for global shortcuts and text injection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if appState.permissionsService.accessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Request") {
                            appState.permissionsService.requestAccessibilityPermission()
                        }
                    }
                }
            }
            
            Section {
                Button("Refresh Permissions Status") {
                    Task {
                        await appState.permissionsService.checkAllPermissions()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("LocalWispr")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Local voice-to-text transcription powered by WhisperKit")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(spacing: 4) {
                Text("100% Offline • No Data Sent")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("Your audio never leaves your device")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
