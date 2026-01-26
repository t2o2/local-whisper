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
    
    // MARK: - Services
    let permissionsService: PermissionsService
    let audioService: AudioCaptureService
    let transcriptionService: TranscriptionService
    let textInjectionService: TextInjectionService
    let coordinator: TranscriptionCoordinator
    
    private init() {
        // Load settings from UserDefaults
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "large-v3"
        self.language = UserDefaults.standard.string(forKey: "language") ?? "en"
        self.useClipboardFallback = UserDefaults.standard.object(forKey: "useClipboardFallback") as? Bool ?? true
        
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
    }
}
