import Foundation
import WhisperKit

/// Handles local transcription using WhisperKit
actor TranscriptionService {
    private var whisperKit: WhisperKit?
    private var isLoading = false
    
    private let progressContinuation: AsyncStream<Double>.Continuation
    let loadProgressStream: AsyncStream<Double>
    
    var isModelLoaded: Bool {
        whisperKit != nil
    }
    
    init() {
        var continuation: AsyncStream<Double>.Continuation!
        self.loadProgressStream = AsyncStream { continuation = $0 }
        self.progressContinuation = continuation
    }
    
    /// Load the Whisper model
    func loadModel(modelName: String = "large-v3") async {
        guard !isLoading && whisperKit == nil else { return }
        
        isLoading = true
        progressContinuation.yield(0.0)
        
        do {
            progressContinuation.yield(0.1)
            
            // Initialize WhisperKit with model variant
            whisperKit = try await WhisperKit(model: modelName)
            
            progressContinuation.yield(1.0)
            print("[TranscriptionService] Model \(modelName) loaded successfully")
        } catch {
            print("[TranscriptionService] Failed to load model: \(error)")
            progressContinuation.yield(0.0)
        }
        
        isLoading = false
    }
    
    /// Transcribe audio data to text
    func transcribe(_ audio: AudioData, language: String = "en") async throws -> String {
        guard let whisper = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        
        guard !audio.isTooShort else {
            throw TranscriptionError.audioTooShort
        }
        
        let options = DecodingOptions(
            task: .transcribe,
            language: language.isEmpty ? nil : language,
            usePrefillPrompt: false,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        
        let results = try await whisper.transcribe(
            audioArray: audio.samples,
            decodeOptions: options
        )
        
        // Combine all segments into final text
        let text = results.compactMap { $0.text }.joined(separator: " ")
        
        // Clean up the text
        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    /// Unload the model to free memory
    func unloadModel() {
        whisperKit = nil
    }
}

// MARK: - Errors
enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case audioTooShort
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded"
        case .audioTooShort:
            return "Audio is too short to transcribe"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}
