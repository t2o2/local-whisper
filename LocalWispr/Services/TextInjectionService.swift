import Foundation
import AppKit
import Carbon.HIToolbox

/// Injects transcribed text into the currently focused application
actor TextInjectionService {
    
    /// Inject text using the best available method
    func injectText(_ text: String, useClipboardFallback: Bool = true) async throws {
        // First, try AXUIElement-based injection
        if try await injectViaAccessibility(text) {
            return
        }
        
        // Fall back to clipboard method if enabled
        if useClipboardFallback {
            try await injectViaClipboard(text)
        } else {
            throw TextInjectionError.injectionFailed
        }
    }
    
    /// Inject text using Accessibility API (preferred method)
    private func injectViaAccessibility(_ text: String) async throws -> Bool {
        // Get the system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()
        
        // Get the focused element
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard focusResult == .success,
              let element = focusedElement else {
            return false
        }
        
        // Try to set the value directly
        let setResult = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )
        
        if setResult == .success {
            return true
        }
        
        // Try inserting at selection (for text views that don't support setValue)
        let insertResult = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        
        return insertResult == .success
    }
    
    /// Inject text via clipboard and Cmd+V (fallback method)
    private func injectViaClipboard(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        
        // Save current clipboard contents
        let previousContents = pasteboard.string(forType: .string)
        
        // Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Small delay to ensure clipboard is updated
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Simulate Cmd+V
        simulatePaste()
        
        // Wait for paste to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Restore previous clipboard contents
        if let previous = previousContents {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }
    
    /// Simulate Cmd+V keypress
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down for V with Command modifier
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
        // Key up for V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
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
