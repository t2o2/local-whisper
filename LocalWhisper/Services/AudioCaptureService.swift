import Foundation
import AVFoundation

/// Captures audio from the microphone in Whisper-compatible format (16kHz mono Float32)
actor AudioCaptureService {
    private var audioEngine: AVAudioEngine?
    private var audioBuffers: [Float] = []
    private var isCurrentlyRecording = false
    
    // Whisper requires 16kHz sample rate
    private let targetSampleRate: Double = 16000
    
    var isRecording: Bool {
        isCurrentlyRecording
    }
    
    func startRecording() async throws {
        guard !isCurrentlyRecording else {
            throw AudioCaptureError.alreadyRecording
        }
        
        audioBuffers.removeAll()
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create converter format for 16kHz mono
        guard let converterFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatError
        }
        
        // Create converter if sample rates differ
        let converter: AVAudioConverter?
        if inputFormat.sampleRate != targetSampleRate || inputFormat.channelCount != 1 {
            converter = AVAudioConverter(from: inputFormat, to: converterFormat)
        } else {
            converter = nil
        }
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            Task {
                await self?.processBuffer(buffer, converter: converter, outputFormat: converterFormat)
            }
        }
        
        engine.prepare()
        try engine.start()
        
        self.audioEngine = engine
        isCurrentlyRecording = true
    }
    
    func stopRecording() async -> AudioData {
        isCurrentlyRecording = false
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        let samples = audioBuffers
        audioBuffers.removeAll()
        
        return AudioData(samples: samples)
    }
    
    private func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter?,
        outputFormat: AVAudioFormat
    ) {
        guard isCurrentlyRecording else { return }
        
        let samples: [Float]
        
        if let converter = converter {
            // Convert to 16kHz mono
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate
            )
            
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: frameCapacity
            ) else { return }
            
            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            guard status != .error, let channelData = convertedBuffer.floatChannelData?[0] else {
                return
            }
            
            samples = Array(UnsafeBufferPointer(
                start: channelData,
                count: Int(convertedBuffer.frameLength)
            ))
        } else {
            // Already in correct format
            guard let channelData = buffer.floatChannelData?[0] else { return }
            samples = Array(UnsafeBufferPointer(
                start: channelData,
                count: Int(buffer.frameLength)
            ))
        }
        
        audioBuffers.append(contentsOf: samples)
    }
}

// MARK: - Errors
enum AudioCaptureError: LocalizedError {
    case alreadyRecording
    case formatError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .formatError:
            return "Failed to configure audio format"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}
