import Foundation

/// Represents the current state of the transcription workflow
enum TranscriptionState: Equatable, CustomStringConvertible {
    case idle
    case recording
    case transcribing
    case error(String)
    
    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .recording, .transcribing:
            return true
        default:
            return false
        }
    }
    
    static func == (lhs: TranscriptionState, rhs: TranscriptionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.transcribing, .transcribing):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}
