import SwiftUI
import Combine

/// Global application state container
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Published State
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var lastTranscription: String = ""
    @Published var errorMessage: String?
    @Published var modelLoadProgress: Double = 0.0
    @Published var isModelLoaded: Bool = false
    
    // MARK: - Settings (stored in UserDefaults)
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    @Published var useClipboardFallback: Bool {
        didSet { UserDefaults.standard.set(useClipboardFallback, forKey: "useClipboardFallback") }
    }
    @Published var customVocabulary: [String] {
        didSet { UserDefaults.standard.set(customVocabulary, forKey: "customVocabulary") }
    }
    
    // MARK: - Proxy Settings
    @Published var proxyEnabled: Bool {
        didSet { 
            UserDefaults.standard.set(proxyEnabled, forKey: "proxyEnabled")
            applyProxySettings()
        }
    }
    @Published var proxyHost: String {
        didSet { 
            UserDefaults.standard.set(proxyHost, forKey: "proxyHost")
            applyProxySettings()
        }
    }
    @Published var proxyPort: String {
        didSet { 
            UserDefaults.standard.set(proxyPort, forKey: "proxyPort")
            applyProxySettings()
        }
    }
    @Published var proxyType: ProxyType {
        didSet { 
            UserDefaults.standard.set(proxyType.rawValue, forKey: "proxyType")
            applyProxySettings()
        }
    }
    
    enum ProxyType: String, CaseIterable {
        case http = "HTTP"
        case https = "HTTPS"
        case socks5 = "SOCKS5"
    }
    
    /// Apply proxy settings to environment variables
    func applyProxySettings() {
        if proxyEnabled && !proxyHost.isEmpty && !proxyPort.isEmpty {
            let proxyURL: String
            switch proxyType {
            case .http:
                proxyURL = "http://\(proxyHost):\(proxyPort)"
                setenv("HTTP_PROXY", proxyURL, 1)
                setenv("http_proxy", proxyURL, 1)
            case .https:
                proxyURL = "http://\(proxyHost):\(proxyPort)"
                setenv("HTTPS_PROXY", proxyURL, 1)
                setenv("https_proxy", proxyURL, 1)
                setenv("HTTP_PROXY", proxyURL, 1)
                setenv("http_proxy", proxyURL, 1)
            case .socks5:
                proxyURL = "socks5://\(proxyHost):\(proxyPort)"
                setenv("ALL_PROXY", proxyURL, 1)
                setenv("all_proxy", proxyURL, 1)
            }
            print("[AppState] Proxy configured: \(proxyType.rawValue) \(proxyHost):\(proxyPort)")
        } else {
            // Clear proxy environment variables
            unsetenv("HTTP_PROXY")
            unsetenv("http_proxy")
            unsetenv("HTTPS_PROXY")
            unsetenv("https_proxy")
            unsetenv("ALL_PROXY")
            unsetenv("all_proxy")
            print("[AppState] Proxy disabled")
        }
    }
    
    /// Returns custom vocabulary as a prompt string for the transcription model
    var vocabularyPrompt: String? {
        guard !customVocabulary.isEmpty else { return nil }
        return customVocabulary.joined(separator: ", ")
    }
    
    // MARK: - Services
    let permissionsService: PermissionsService
    let audioService: AudioCaptureService
    let transcriptionService: TranscriptionService
    let textInjectionService: TextInjectionService
    let coordinator: TranscriptionCoordinator
    
    private init() {
        // Load settings from UserDefaults
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "openai_whisper-base"
        self.language = UserDefaults.standard.string(forKey: "language") ?? "en"
        self.useClipboardFallback = UserDefaults.standard.object(forKey: "useClipboardFallback") as? Bool ?? true
        self.customVocabulary = UserDefaults.standard.stringArray(forKey: "customVocabulary") ?? []
        
        // Load proxy settings
        self.proxyEnabled = UserDefaults.standard.bool(forKey: "proxyEnabled")
        self.proxyHost = UserDefaults.standard.string(forKey: "proxyHost") ?? "127.0.0.1"
        self.proxyPort = UserDefaults.standard.string(forKey: "proxyPort") ?? "1087"
        if let proxyTypeRaw = UserDefaults.standard.string(forKey: "proxyType"),
           let type = ProxyType(rawValue: proxyTypeRaw) {
            self.proxyType = type
        } else {
            self.proxyType = .http
        }
        
        self.permissionsService = PermissionsService()
        self.audioService = AudioCaptureService()
        self.transcriptionService = TranscriptionService()
        self.textInjectionService = TextInjectionService()
        self.coordinator = TranscriptionCoordinator()
        
        // Inject dependencies after init
        coordinator.configure(
            appState: self,
            audioService: audioService,
            transcriptionService: transcriptionService,
            textInjectionService: textInjectionService
        )
        
        // Observe transcription service state
        Task {
            for await progress in transcriptionService.loadProgressStream {
                self.modelLoadProgress = progress
            }
        }
        
        // Apply proxy settings on startup
        applyProxySettings()
    }
}
