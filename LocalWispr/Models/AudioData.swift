import Foundation
import AVFoundation

/// Container for captured audio data in whisper-compatible format
struct AudioData {
    /// Audio samples as Float32 array (16kHz mono)
    let samples: [Float]
    
    /// Sample rate (always 16000 for Whisper)
    let sampleRate: Int = 16000
    
    /// Duration in seconds
    var duration: TimeInterval {
        Double(samples.count) / Double(sampleRate)
    }
    
    /// Check if audio is too short to transcribe
    var isTooShort: Bool {
        duration < 0.5
    }
    
    /// Check if audio is too long (> 30 minutes)
    var isTooLong: Bool {
        duration > 1800
    }
    
    init(samples: [Float]) {
        self.samples = samples
    }
    
    /// Create from AVAudioPCMBuffer
    init?(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else {
            return nil
        }
        let frameCount = Int(buffer.frameLength)
        self.samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
    }
}
