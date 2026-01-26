import Foundation
import AVFoundation
import AppKit

/// Handles checking and requesting macOS permissions
@MainActor
final class PermissionsService: ObservableObject {
    @Published var microphoneGranted: Bool = false
    @Published var accessibilityGranted: Bool = false
    
    var allPermissionsGranted: Bool {
        microphoneGranted && accessibilityGranted
    }
    
    func checkAllPermissions() async {
        await checkMicrophonePermission()
        checkAccessibilityPermission()
    }
    
    // MARK: - Microphone Permission
    
    func checkMicrophonePermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            microphoneGranted = await requestMicrophonePermission()
        case .denied, .restricted:
            microphoneGranted = false
        @unknown default:
            microphoneGranted = false
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Accessibility Permission
    
    func checkAccessibilityPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        // This opens System Preferences to the Accessibility pane
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Open System Settings
    
    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
