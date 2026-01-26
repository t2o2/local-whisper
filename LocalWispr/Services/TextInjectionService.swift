import Foundation
import AppKit
import Carbon.HIToolbox
import os.log

private let injectionLogger = Logger(subsystem: "com.localwispr.app", category: "TextInjection")

/// Injects transcribed text into the currently focused application
actor TextInjectionService {
    
    /// Inject text - copies to clipboard and auto-pastes
    func injectText(_ text: String, useClipboardFallback: Bool = true) async throws {
        injectionLogger.info("Injecting text: \(text.prefix(50))...")
        
        // Step 1: Copy to clipboard
        copyToClipboard(text)
        injectionLogger.info("Text copied to clipboard")
        
        // Step 2: Small delay to ensure clipboard is ready
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Step 3: Simulate Cmd+V to paste
        simulatePaste()
        injectionLogger.info("Paste command sent")
    }
    
    /// Copy text to clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Simulate Cmd+V keypress using CGEvent
    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // V key = keycode 9
        let vKeyCode: CGKeyCode = 9
        
        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            injectionLogger.error("Failed to create keyDown event")
            return
        }
        
        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            injectionLogger.error("Failed to create keyUp event")
            return
        }
        
        // Set Command modifier for both events
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post events to HID tap (works with accessibility permission)
        keyDown.post(tap: .cghidEventTap)
        usleep(5000) // 5ms delay between key down and up
        keyUp.post(tap: .cghidEventTap)
        
        injectionLogger.info("Cmd+V keystroke posted")
    }
}

// MARK: - Errors
enum TextInjectionError: LocalizedError {
    case injectionFailed
    case accessibilityNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .injectionFailed:
            return "Failed to inject text into the focused application"
        case .accessibilityNotAvailable:
            return "Accessibility permission is required for text injection"
        }
    }
}
