import Foundation
import SwiftUI

/// Orchestrates the hotkey → record → transcribe → inject workflow
@MainActor
final class TranscriptionCoordinator: ObservableObject {
    private weak var appState: AppState?
    private var audioService: AudioCaptureService?
    private var transcriptionService: TranscriptionService?
    private var textInjectionService: TextInjectionService?
    
    private var recordingTask: Task<Void, Never>?
    
    func configure(
        appState: AppState,
        audioService: AudioCaptureService,
        transcriptionService: TranscriptionService,
        textInjectionService: TextInjectionService
    ) {
        self.appState = appState
        self.audioService = audioService
        self.transcriptionService = transcriptionService
        self.textInjectionService = textInjectionService
    }
    
    /// Called when hotkey is pressed - start recording
    func handleHotkeyPressed() async {
        guard let appState = appState,
              let audioService = audioService else { return }
        
        // Check if model is loaded
        guard await transcriptionService?.isModelLoaded == true else {
            appState.errorMessage = "Model not loaded yet. Please wait..."
            return
        }
        
        // Check permissions
        guard appState.permissionsService.allPermissionsGranted else {
            appState.errorMessage = "Please grant microphone and accessibility permissions"
            return
        }
        
        // If already recording, treat as toggle (stop)
        if appState.transcriptionState == .recording {
            await handleHotkeyReleased()
            return
        }
        
        // Start recording
        do {
            appState.transcriptionState = .recording
            appState.errorMessage = nil
            try await audioService.startRecording()
            print("[Coordinator] Recording started")
        } catch {
            appState.transcriptionState = .error(error.localizedDescription)
            appState.errorMessage = error.localizedDescription
            print("[Coordinator] Failed to start recording: \(error)")
        }
    }
    
    /// Called when hotkey is released - stop recording and transcribe
    func handleHotkeyReleased() async {
        guard let appState = appState,
              let audioService = audioService,
              let transcriptionService = transcriptionService,
              let textInjectionService = textInjectionService else { return }
        
        guard appState.transcriptionState == .recording else { return }
        
        // Stop recording
        let audioData = await audioService.stopRecording()
        print("[Coordinator] Recording stopped, duration: \(String(format: "%.2f", audioData.duration))s")
        
        // Check if too short
        guard !audioData.isTooShort else {
            appState.transcriptionState = .idle
            appState.errorMessage = "Recording too short"
            return
        }
        
        // Transcribe
        appState.transcriptionState = .transcribing
        
        do {
            let text = try await transcriptionService.transcribe(
                audioData,
                language: appState.language
            )
            
            print("[Coordinator] Transcription: \(text)")
            appState.lastTranscription = text
            
            // Inject text
            if !text.isEmpty {
                try await textInjectionService.injectText(
                    text,
                    useClipboardFallback: appState.useClipboardFallback
                )
            }
            
            appState.transcriptionState = .idle
            appState.errorMessage = nil
            
        } catch {
            appState.transcriptionState = .error(error.localizedDescription)
            appState.errorMessage = error.localizedDescription
            print("[Coordinator] Transcription failed: \(error)")
            
            // Reset to idle after showing error
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                if case .error = appState.transcriptionState {
                    appState.transcriptionState = .idle
                }
            }
        }
    }
    
    /// Cancel current operation
    func cancel() async {
        guard let appState = appState,
              let audioService = audioService else { return }
        
        if appState.transcriptionState == .recording {
            _ = await audioService.stopRecording()
        }
        
        recordingTask?.cancel()
        appState.transcriptionState = .idle
    }
}
