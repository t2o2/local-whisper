import Foundation
import AppKit
import Carbon.HIToolbox

/// Manages global keyboard shortcuts using CGEvent API
final class HotkeyManager {
    static let shared = HotkeyManager()
    
    // Default shortcut: Cmd+Shift+Space
    private(set) var keyCode: UInt16 = UInt16(kVK_Space)
    private(set) var modifiers: CGEventFlags = [.maskCommand, .maskShift]
    
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    
    private var isKeyDown = false
    
    private init() {}
    
    /// Start monitoring for global hotkey
    func start() {
        guard eventTap == nil else { return }
        
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            print("[HotkeyManager] Accessibility permission not granted")
            return
        }
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                      (1 << CGEventType.keyUp.rawValue) |
                                      (1 << CGEventType.flagsChanged.rawValue)
        
        // Create event tap with a thin wrapper callback
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[HotkeyManager] Failed to create event tap")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[HotkeyManager] Started monitoring for hotkey")
        }
    }
    
    /// Stop monitoring
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        print("[HotkeyManager] Stopped monitoring")
    }
    
    /// Handle keyboard event
    fileprivate func handleEvent(_ event: CGEvent) -> Bool {
        let type = event.type
        let currentKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let currentFlags = event.flags
        
        // Check if our hotkey modifiers are pressed
        let hasRequiredModifiers = currentFlags.contains(.maskCommand) && currentFlags.contains(.maskShift)
        
        switch type {
        case .keyDown:
            if currentKeyCode == keyCode && hasRequiredModifiers && !isKeyDown {
                isKeyDown = true
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyDown?()
                }
                return true // Consume the event
            }
            
        case .keyUp:
            if currentKeyCode == keyCode && isKeyDown {
                isKeyDown = false
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyUp?()
                }
                return true // Consume the event
            }
            
        case .flagsChanged:
            // Handle case where modifiers are released before the key
            if isKeyDown && !hasRequiredModifiers {
                isKeyDown = false
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyUp?()
                }
            }
            
        default:
            break
        }
        
        return false // Don't consume the event
    }
    
    /// Update the hotkey
    func setHotkey(keyCode: UInt16, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        
        // Save to UserDefaults
        UserDefaults.standard.set(Int(keyCode), forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(modifiers.rawValue, forKey: "hotkeyModifiers")
    }
    
    /// Load saved hotkey from UserDefaults
    func loadSavedHotkey() {
        if let savedKeyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int {
            keyCode = UInt16(savedKeyCode)
        }
        if let savedModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt64 {
            modifiers = CGEventFlags(rawValue: savedModifiers)
        }
    }
    
    /// Get human-readable shortcut string
    var shortcutString: String {
        var parts: [String] = []
        
        if modifiers.contains(.maskControl) { parts.append("⌃") }
        if modifiers.contains(.maskAlternate) { parts.append("⌥") }
        if modifiers.contains(.maskShift) { parts.append("⇧") }
        if modifiers.contains(.maskCommand) { parts.append("⌘") }
        
        // Convert key code to string
        let keyString: String
        switch Int(keyCode) {
        case kVK_Space: keyString = "Space"
        case kVK_Return: keyString = "Return"
        case kVK_Tab: keyString = "Tab"
        case kVK_Escape: keyString = "Esc"
        default:
            // Try to get the character
            if let char = keyCodeToString(keyCode) {
                keyString = char.uppercased()
            } else {
                keyString = "Key\(keyCode)"
            }
        }
        
        parts.append(keyString)
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        let keyboard = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(keyboard, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        
        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)
        
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var actualLength: Int = 0
        
        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &actualLength,
            &chars
        )
        
        guard status == noErr, actualLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: actualLength)
    }
}

// MARK: - CGEvent Callback
private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    
    // Handle tap disabled event
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = HotkeyManager.shared.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }
    
    guard let userInfo = userInfo else {
        return Unmanaged.passRetained(event)
    }
    
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    
    if manager.handleEvent(event) {
        return nil // Consume the event
    }
    
    return Unmanaged.passRetained(event)
}
