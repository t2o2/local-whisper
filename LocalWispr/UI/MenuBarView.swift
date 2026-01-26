import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            Divider()
            
            // Status Section
            statusSection
            
            // Permissions Section (if needed)
            if !appState.permissionsService.allPermissionsGranted {
                Divider()
                permissionsSection
            }
            
            Divider()
            
            // Last Transcription
            if !appState.lastTranscription.isEmpty {
                lastTranscriptionSection
                Divider()
            }
            
            // Shortcut Info
            shortcutSection
            
            Divider()
            
            // Actions
            actionsSection
        }
        .padding()
        .frame(width: 320)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text("LocalWispr")
                .font(.headline)
            
            Spacer()
            
            statusBadge
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(appState.transcriptionState.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch appState.transcriptionState {
        case .idle:
            return appState.isModelLoaded ? .green : .yellow
        case .recording:
            return .red
        case .transcribing:
            return .blue
        case .error:
            return .orange
        }
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Model Status
            HStack {
                Image(systemName: appState.isModelLoaded ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundColor(appState.isModelLoaded ? .green : .orange)
                
                if appState.isModelLoaded {
                    Text("Model loaded: \(appState.selectedModel)")
                        .font(.caption)
                } else if appState.modelLoadProgress > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loading model...")
                            .font(.caption)
                        ProgressView(value: appState.modelLoadProgress)
                            .progressViewStyle(.linear)
                    }
                } else {
                    Text("Model not loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Error Message
            if let error = appState.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Permissions Section
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions Required")
                .font(.caption)
                .fontWeight(.semibold)
            
            // Microphone
            MenuPermissionRow(
                icon: "mic.fill",
                title: "Microphone",
                granted: appState.permissionsService.microphoneGranted,
                action: { appState.permissionsService.openMicrophoneSettings() }
            )
            
            // Accessibility
            MenuPermissionRow(
                icon: "accessibility",
                title: "Accessibility",
                granted: appState.permissionsService.accessibilityGranted,
                action: { appState.permissionsService.requestAccessibilityPermission() }
            )
        }
    }
    
    // MARK: - Last Transcription
    @State private var showCopiedFeedback = false
    
    private var lastTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Last Transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if showCopiedFeedback {
                    Text("Copied!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            
            Button(action: copyTranscriptionToClipboard) {
                Text(appState.lastTranscription)
                    .font(.body)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Click to copy to clipboard")
            
            Text("Click to copy")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func copyTranscriptionToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(appState.lastTranscription, forType: .string)
        
        withAnimation {
            showCopiedFeedback = true
        }
        
        // Hide feedback after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
    
    // MARK: - Shortcut Section
    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keyboard Shortcut")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(HotkeyManager.shared.shortcutString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("Hold to record")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        HStack {
            Button("Settings...") {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.showSettings()
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .font(.caption)
    }
}

// MARK: - Menu Permission Row (simplified version for menu)
struct MenuPermissionRow: View {
    let icon: String
    let title: String
    let granted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
            
            Text(title)
                .font(.caption)
            
            Spacer()
            
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
