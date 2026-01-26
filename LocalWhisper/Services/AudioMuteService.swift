import Foundation
import CoreAudio

/// Service to mute/unmute system audio output during recording
/// This prevents the microphone from picking up speaker audio during transcription
actor AudioMuteService {
    private var previousMuteState: Bool = false
    private var isMutedByUs: Bool = false
    
    /// Mute the system audio output and save the previous state
    func muteSystemAudio() async throws {
        let deviceID = try getDefaultOutputDevice()
        
        // Save current mute state so we can restore it later
        previousMuteState = try getMuteState(deviceID: deviceID)
        
        // Only mute if not already muted
        if !previousMuteState {
            try setMuteState(deviceID: deviceID, muted: true)
            isMutedByUs = true
            print("[AudioMuteService] System audio muted")
        } else {
            print("[AudioMuteService] System was already muted, skipping")
        }
    }
    
    /// Restore the system audio to its previous state
    func restoreSystemAudio() async throws {
        guard isMutedByUs else {
            print("[AudioMuteService] We didn't mute, skipping restore")
            return
        }
        
        let deviceID = try getDefaultOutputDevice()
        
        // Restore to previous state (unmute if it wasn't muted before)
        try setMuteState(deviceID: deviceID, muted: previousMuteState)
        isMutedByUs = false
        print("[AudioMuteService] System audio restored to previous state (muted: \(previousMuteState))")
    }
    
    /// Force unmute regardless of previous state (safety method)
    func forceUnmute() async throws {
        let deviceID = try getDefaultOutputDevice()
        try setMuteState(deviceID: deviceID, muted: false)
        isMutedByUs = false
        print("[AudioMuteService] System audio force unmuted")
    }
    
    // MARK: - Private CoreAudio Methods
    
    private func getDefaultOutputDevice() throws -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            throw AudioMuteError.failedToGetDevice(status)
        }
        
        return deviceID
    }
    
    private func getMuteState(deviceID: AudioDeviceID) throws -> Bool {
        var muted: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &muted
        )
        
        guard status == noErr else {
            throw AudioMuteError.failedToGetMuteState(status)
        }
        
        return muted != 0
    }
    
    private func setMuteState(deviceID: AudioDeviceID, muted: Bool) throws {
        var muteValue: UInt32 = muted ? 1 : 0
        let propertySize = UInt32(MemoryLayout<UInt32>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            propertySize,
            &muteValue
        )
        
        guard status == noErr else {
            throw AudioMuteError.failedToSetMuteState(status)
        }
    }
}

// MARK: - Errors

enum AudioMuteError: LocalizedError {
    case failedToGetDevice(OSStatus)
    case failedToGetMuteState(OSStatus)
    case failedToSetMuteState(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .failedToGetDevice(let status):
            return "Failed to get default output device (error: \(status))"
        case .failedToGetMuteState(let status):
            return "Failed to get mute state (error: \(status))"
        case .failedToSetMuteState(let status):
            return "Failed to set mute state (error: \(status))"
        }
    }
}
