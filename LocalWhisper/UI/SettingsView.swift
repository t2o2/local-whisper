import SwiftUI
import Carbon.HIToolbox

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("Model", systemImage: "cpu")
                    .tag(0)
                Label("Vocabulary", systemImage: "text.book.closed")
                    .tag(1)
                Label("Shortcuts", systemImage: "keyboard")
                    .tag(2)
                Label("Network", systemImage: "network")
                    .tag(3)
                Label("Permissions", systemImage: "lock.shield")
                    .tag(4)
                Label("About", systemImage: "info.circle")
                    .tag(5)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 150)
        } detail: {
            Group {
                switch selectedTab {
                case 0:
                    ModelSettingsView()
                case 1:
                    VocabularySettingsView()
                case 2:
                    ShortcutSettingsView()
                case 3:
                    NetworkSettingsView()
                case 4:
                    PermissionsSettingsView()
                case 5:
                    AboutView()
                default:
                    ModelSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 600, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(appState)
    }
}

// MARK: - Model Settings
struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isReloading = false
    @State private var selectedModelIndex = 0
    
    private let models: [(id: String, name: String, size: String, description: String)] = [
        ("openai_whisper-tiny", "Tiny", "~75MB", "Fastest, basic accuracy"),
        ("openai_whisper-base", "Base", "~140MB", "Fast, good for most uses"),
        ("openai_whisper-small", "Small", "~460MB", "Balanced speed & accuracy"),
        ("openai_whisper-medium", "Medium", "~1.5GB", "High accuracy"),
        ("openai_whisper-large-v3", "Large v3", "~3GB", "Best accuracy"),
        ("openai_whisper-large-v3_turbo", "Large v3 Turbo", "~1.6GB", "Fast & accurate")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Whisper Model")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Choose a model based on your needs. Larger models are more accurate but slower.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Current Status
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(appState.isModelLoaded ? Color.green.opacity(0.2) : Color.yellow.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: appState.isModelLoaded ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(appState.isModelLoaded ? .green : .yellow)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.isModelLoaded ? "Model Ready" : "Loading Model...")
                            .font(.headline)
                        Text(appState.selectedModel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !appState.isModelLoaded && appState.modelLoadProgress > 0 {
                        ProgressView(value: appState.modelLoadProgress)
                            .frame(width: 100)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                // Model Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Model")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(models, id: \.id) { model in
                            ModelCard(
                                model: model,
                                isSelected: appState.selectedModel == model.id,
                                isLoading: isReloading && appState.selectedModel == model.id
                            ) {
                                selectModel(model.id)
                            }
                        }
                    }
                }
                
                // Language Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Language")
                        .font(.headline)
                    
                    Picker("", selection: $appState.language) {
                        Text("English").tag("en")
                        Text("Auto-detect").tag("")
                        Divider()
                        Text("Chinese").tag("zh")
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                        Text("Japanese").tag("ja")
                        Text("Korean").tag("ko")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                
                // Recording Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recording Options")
                        .font(.headline)
                    
                    Toggle(isOn: $appState.muteAudioWhileRecording) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mute speakers while recording")
                            Text("Prevents the microphone from picking up audio playing from your speakers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    private func selectModel(_ modelId: String) {
        guard modelId != appState.selectedModel || !appState.isModelLoaded else { return }
        
        appState.selectedModel = modelId
        isReloading = true
        
        Task {
            await appState.transcriptionService.unloadModel()
            await MainActor.run {
                appState.isModelLoaded = false
            }
            await appState.transcriptionService.loadModel(modelName: modelId)
            let loaded = await appState.transcriptionService.isModelLoaded
            await MainActor.run {
                appState.isModelLoaded = loaded
                isReloading = false
            }
        }
    }
}

// MARK: - Model Card
struct ModelCard: View {
    let model: (id: String, name: String, size: String, description: String)
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                
                Text(model.size)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                
                Text(model.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vocabulary Settings
struct VocabularySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newWord = ""
    @State private var editingIndex: Int?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Vocabulary")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Add words or phrases to improve transcription accuracy for names, technical terms, or domain-specific vocabulary.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Add new word
                HStack(spacing: 12) {
                    TextField("Add a word or phrase...", text: $newWord)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addWord()
                        }
                    
                    Button(action: addWord) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                // Word list
                if appState.customVocabulary.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No custom words yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Add words that you frequently use or that are often misheard.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(appState.customVocabulary.enumerated()), id: \.offset) { index, word in
                            HStack {
                                Text(word)
                                    .font(.body)
                                
                                Spacer()
                                
                                Button {
                                    removeWord(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            if index < appState.customVocabulary.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tips", systemImage: "lightbulb")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        tipRow("Add proper nouns, names, and brand names")
                        tipRow("Include technical terms or jargon")
                        tipRow("Add words that are often misheard or misspelled")
                        tipRow("Use correct capitalization for names")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
    
    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !appState.customVocabulary.contains(trimmed) else {
            newWord = ""
            return
        }
        
        withAnimation {
            appState.customVocabulary.append(trimmed)
        }
        newWord = ""
    }
    
    private func removeWord(at index: Int) {
        _ = withAnimation {
            appState.customVocabulary.remove(at: index)
        }
    }
}

// MARK: - Shortcut Settings
struct ShortcutSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    @State private var currentShortcut = HotkeyManager.shared.shortcutString
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure how you trigger voice transcription.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Current shortcut
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recording Shortcut")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        // Shortcut display / recorder
                        ShortcutRecorderView(
                            isRecording: $isRecording,
                            currentShortcut: $currentShortcut
                        )
                        
                        Spacer()
                        
                        if !isRecording {
                            Button("Change") {
                                isRecording = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    
                    Text("Hold to record, release to transcribe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Preset shortcuts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Presets")
                        .font(.headline)
                    
                    // First row - Primary options
                    HStack(spacing: 12) {
                        PresetShortcutButton(
                            label: "🎙️ Mic Key",
                            keyCode: 179,  // Globe/Fn key with mic icon on modern Macs
                            modifiers: [],
                            currentShortcut: $currentShortcut,
                            isRecommended: true
                        )
                        
                        PresetShortcutButton(
                            label: "⌃⇧Space",
                            keyCode: UInt16(kVK_Space),
                            modifiers: [.maskControl, .maskShift],
                            currentShortcut: $currentShortcut
                        )
                    }
                    
                    // Second row
                    HStack(spacing: 12) {
                        PresetShortcutButton(
                            label: "⌥Space",
                            keyCode: UInt16(kVK_Space),
                            modifiers: [.maskAlternate],
                            currentShortcut: $currentShortcut
                        )
                        
                        PresetShortcutButton(
                            label: "Fn+F5",
                            keyCode: UInt16(kVK_F5),
                            modifiers: [],
                            currentShortcut: $currentShortcut
                        )
                    }
                    
                    // Instructions for Mic Key
                    VStack(alignment: .leading, spacing: 8) {
                        Label("To use the 🎙️ Mic Key", systemImage: "info.circle")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("1. Open System Settings → Keyboard → Dictation\n2. Turn OFF Dictation (or change its shortcut)\n3. Select \"🎙️ Mic Key\" above")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Usage instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Use")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        InstructionRow(number: 1, text: "Press and hold the shortcut keys")
                        InstructionRow(number: 2, text: "Speak clearly into your microphone")
                        InstructionRow(number: 3, text: "Release the keys to transcribe")
                        InstructionRow(number: 4, text: "Text is automatically pasted")
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - Shortcut Recorder View
struct ShortcutRecorderView: View {
    @Binding var isRecording: Bool
    @Binding var currentShortcut: String
    
    var body: some View {
        ZStack {
            if isRecording {
                ShortcutRecorderField(
                    isRecording: $isRecording,
                    currentShortcut: $currentShortcut
                )
            } else {
                // Display current shortcut
                HStack(spacing: 4) {
                    ForEach(parseShortcut(currentShortcut), id: \.self) { part in
                        if part == "+" {
                            Text("+")
                                .foregroundStyle(.secondary)
                        } else {
                            KeyCap(part)
                        }
                    }
                }
            }
        }
    }
    
    private func parseShortcut(_ shortcut: String) -> [String] {
        var parts: [String] = []
        var current = shortcut
        
        let modifiers = ["⌃", "⌥", "⇧", "⌘"]
        for mod in modifiers {
            if current.hasPrefix(mod) {
                parts.append(mod)
                parts.append("+")
                current = String(current.dropFirst())
            }
        }
        
        if !current.isEmpty {
            parts.append(current)
        }
        
        // Remove trailing +
        if parts.last == "+" {
            parts.removeLast()
        }
        
        return parts
    }
}

// MARK: - Shortcut Recorder Field (NSView wrapper)
struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var currentShortcut: String
    
    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onShortcutRecorded = { keyCode, modifiers in
            HotkeyManager.shared.setHotkey(keyCode: keyCode, modifiers: modifiers)
            currentShortcut = HotkeyManager.shared.shortcutString
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }
    
    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        if isRecording {
            // Ensure the view becomes first responder and starts monitoring
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.startMonitoring()
            }
        } else {
            nsView.stopMonitoring()
        }
    }
}

class ShortcutRecorderNSView: NSView {
    var onShortcutRecorded: ((UInt16, CGEventFlags) -> Void)?
    var onCancel: (() -> Void)?
    private var eventMonitor: Any?
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw recording indicator
        NSColor.controlBackgroundColor.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        path.fill()
        
        NSColor.systemBlue.setStroke()
        path.lineWidth = 2
        path.stroke()
        
        // Draw text
        let text = "Type your shortcut..."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        text.draw(at: point, withAttributes: attributes)
    }
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: 180, height: 32)
    }
    
    func startMonitoring() {
        guard eventMonitor == nil else { return }
        
        // Use local event monitor to capture key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Escape to cancel
            if event.keyCode == UInt16(kVK_Escape) {
                self.onCancel?()
                return nil // Consume the event
            }
            
            // Get modifiers
            var modifiers: CGEventFlags = []
            if event.modifierFlags.contains(.control) {
                modifiers.insert(.maskControl)
            }
            if event.modifierFlags.contains(.option) {
                modifiers.insert(.maskAlternate)
            }
            if event.modifierFlags.contains(.shift) {
                modifiers.insert(.maskShift)
            }
            if event.modifierFlags.contains(.command) {
                modifiers.insert(.maskCommand)
            }
            
            // Require at least one modifier (unless it's a function key or Globe key)
            let isFunctionKey = (event.keyCode >= UInt16(kVK_F1) && event.keyCode <= UInt16(kVK_F20))
            let isGlobeKey = (event.keyCode == 63 || event.keyCode == 179)  // Fn or Globe key
            
            if modifiers.isEmpty && !isFunctionKey && !isGlobeKey {
                // Beep to indicate need modifier
                NSSound.beep()
                return nil
            }
            
            self.onShortcutRecorded?(event.keyCode, modifiers)
            return nil // Consume the event
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    override func keyDown(with event: NSEvent) {
        // Handled by event monitor, but keep as fallback
    }
}

// MARK: - Preset Shortcut Button
struct PresetShortcutButton: View {
    let label: String
    let keyCode: UInt16
    let modifiers: CGEventFlags
    @Binding var currentShortcut: String
    var isRecommended: Bool = false
    
    var isSelected: Bool {
        HotkeyManager.shared.keyCode == keyCode &&
        HotkeyManager.shared.modifiers == modifiers
    }
    
    var body: some View {
        Button {
            HotkeyManager.shared.setHotkey(keyCode: keyCode, modifiers: modifiers)
            currentShortcut = HotkeyManager.shared.shortcutString
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                if isRecommended && !isSelected {
                    Text("★")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : (isRecommended ? Color.orange.opacity(0.15) : Color(nsColor: .controlBackgroundColor)))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecommended && !isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct KeyCap: View {
    let key: String
    
    init(_ key: String) {
        self.key = key
    }
    
    var body: some View {
        Text(key)
            .font(.system(.body, design: .rounded, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Network Settings
struct NetworkSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var testingConnection = false
    @State private var connectionStatus: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network & Proxy")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure proxy settings for downloading models from HuggingFace.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Proxy Enable Toggle
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $appState.proxyEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Proxy")
                                .font(.headline)
                            Text("Use a proxy server for model downloads")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                // Proxy Configuration
                if appState.proxyEnabled {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Proxy Configuration")
                            .font(.headline)
                        
                        // Proxy Type
                        HStack {
                            Text("Type:")
                                .frame(width: 60, alignment: .leading)
                            Picker("", selection: $appState.proxyType) {
                                ForEach(AppState.ProxyType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                        
                        // Host
                        HStack {
                            Text("Host:")
                                .frame(width: 60, alignment: .leading)
                            TextField("127.0.0.1", text: $appState.proxyHost)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        }
                        
                        // Port
                        HStack {
                            Text("Port:")
                                .frame(width: 60, alignment: .leading)
                            TextField("1087", text: $appState.proxyPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                        
                        // Current proxy URL display
                        if !appState.proxyHost.isEmpty && !appState.proxyPort.isEmpty {
                            HStack {
                                Text("Proxy URL:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(proxyURLString)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Test Connection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Connection")
                            .font(.headline)
                        
                        HStack {
                            Button {
                                testConnection()
                            } label: {
                                if testingConnection {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Label("Test HuggingFace Connection", systemImage: "network")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(testingConnection)
                            
                            if let status = connectionStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundStyle(status.contains("✓") ? .green : .red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                // Help text
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tips", systemImage: "lightbulb")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        tipRow("Common proxy ports: 1080 (SOCKS), 1087 (HTTP), 7890 (Clash)")
                        tipRow("For Clash/V2Ray, use HTTP type with their HTTP proxy port")
                        tipRow("SOCKS5 support depends on the underlying network library")
                        tipRow("After changing proxy, restart the app to apply for model downloads")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    private var proxyURLString: String {
        switch appState.proxyType {
        case .http, .https:
            return "http://\(appState.proxyHost):\(appState.proxyPort)"
        case .socks5:
            return "socks5://\(appState.proxyHost):\(appState.proxyPort)"
        }
    }
    
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
    
    private func testConnection() {
        testingConnection = true
        connectionStatus = nil
        
        Task {
            do {
                let url = URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!
                let (_, response) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse,
                       (200...399).contains(httpResponse.statusCode) {
                        connectionStatus = "✓ Connected successfully"
                    } else {
                        connectionStatus = "✗ Connection failed"
                    }
                    testingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "✗ Error: \(error.localizedDescription)"
                    testingConnection = false
                }
            }
        }
    }
}

// MARK: - Permissions Settings
struct PermissionsSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permissions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("LocalWhisper needs these permissions to work properly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Permission rows
                VStack(spacing: 0) {
                    PermissionRow(
                        icon: "mic.fill",
                        iconColor: .red,
                        title: "Microphone",
                        description: "Required to capture your voice for transcription",
                        isGranted: appState.permissionsService.microphoneGranted
                    ) {
                        appState.permissionsService.openMicrophoneSettings()
                    }
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    PermissionRow(
                        icon: "accessibility",
                        iconColor: .blue,
                        title: "Accessibility",
                        description: "Required for global shortcuts and auto-paste",
                        isGranted: appState.permissionsService.accessibilityGranted
                    ) {
                        appState.permissionsService.requestAccessibilityPermission()
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                
                // Refresh button
                Button {
                    Task {
                        await appState.permissionsService.checkAllPermissions()
                    }
                } label: {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding(24)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button("Grant", action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(16)
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "waveform")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            
            // App name and version
            VStack(spacing: 4) {
                Text("LocalWhisper")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            Text("Local voice-to-text transcription\npowered by WhisperKit")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            // Privacy badge
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
                Text("100% Offline • Your audio never leaves your device")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.1))
            .cornerRadius(20)
            
            Spacer()
            
            // Credits
            VStack(spacing: 4) {
                Text("Built with WhisperKit by Argmax")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("© 2024 LocalWhisper")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
