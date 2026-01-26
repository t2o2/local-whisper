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
    /// Model names from HuggingFace argmaxinc/whisperkit-coreml:
    /// - openai_whisper-tiny, openai_whisper-tiny.en (~75MB, fastest)
    /// - openai_whisper-base, openai_whisper-base.en (~140MB, fast)
    /// - openai_whisper-small, openai_whisper-small.en (~460MB, balanced)
    /// - openai_whisper-medium, openai_whisper-medium.en (~1.5GB, good)
    /// - openai_whisper-large-v3, openai_whisper-large-v3_turbo (~3GB, best)
    func loadModel(modelName: String = "openai_whisper-base") async {
        guard !isLoading && whisperKit == nil else { return }
        
        isLoading = true
        progressContinuation.yield(0.0)
        
        do {
            progressContinuation.yield(0.1)
            print("[TranscriptionService] Loading model: \(modelName)...")
            
            // Initialize WhisperKit with model variant
            // WhisperKit will download from HuggingFace if not cached
            // Use verbose mode to see download progress
            whisperKit = try await WhisperKit(
                model: modelName,
                verbose: true,
                logLevel: .debug,
                prewarm: true,
                load: true,
                download: true
            )
            
            progressContinuation.yield(1.0)
            print("[TranscriptionService] Model \(modelName) loaded successfully")
        } catch {
            print("[TranscriptionService] Failed to load model: \(error)")
            // Try with a smaller model as fallback
            if modelName != "openai_whisper-base" {
                print("[TranscriptionService] Retrying with base model...")
                isLoading = false
                await loadModel(modelName: "openai_whisper-base")
                return
            }
            progressContinuation.yield(0.0)
        }
        
        isLoading = false
    }
    
    /// Transcribe audio data to text
    /// - Parameters:
    ///   - audio: The audio data to transcribe
    ///   - language: Language code (e.g., "en", "zh") or empty for auto-detect
    ///   - prompt: Optional initial prompt with custom vocabulary to improve accuracy
    func transcribe(_ audio: AudioData, language: String = "en", prompt: String? = nil) async throws -> String {
        guard let whisper = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        
        guard !audio.isTooShort else {
            throw TranscriptionError.audioTooShort
        }
        
        // Configure decoding options
        // Note: Custom vocabulary/prompt feature depends on WhisperKit version
        // For now, we use standard decoding options
        let options = DecodingOptions(
            task: .transcribe,
            language: language.isEmpty ? nil : language,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        
        if let prompt = prompt {
            print("[TranscriptionService] Custom vocabulary context: \(prompt)")
            // Future: when WhisperKit supports prompt, use it here
        }
        
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
