import Foundation
import AppKit
import Carbon.HIToolbox
import ObjectiveC
import os.log

private let hotkeyLogger = Logger(subsystem: "com.localwispr.app", category: "HotkeyManager")

/// Manages global keyboard shortcuts using CGEvent API
final class HotkeyManager {
    static let shared = HotkeyManager()
    
    // Default shortcut: Ctrl+Shift+Space
    private(set) var keyCode: UInt16 = UInt16(kVK_Space)
    private(set) var modifiers: CGEventFlags = [.maskControl, .maskShift]
    
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnKeyMonitor: Any?
    private var fnKeyWasPressed = false
    
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
        
        // Create event tap at HID level to intercept before system handlers (like dictation)
        // Using .cghidEventTap captures events at the lowest level, before macOS processes them
        // This allows us to override system shortcuts like F5 (dictation)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,  // HID level - intercepts before system
            place: .headInsertEventTap,  // Insert at head to get first priority
            options: .defaultTap,  // Can modify/consume events
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[HotkeyManager] Failed to create HID event tap, falling back to session tap")
            // Fallback to session tap if HID tap fails
            guard let sessionTap = CGEvent.tapCreate(
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
            eventTap = sessionTap
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, sessionTap, 0)
            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: sessionTap, enable: true)
                print("[HotkeyManager] Started monitoring with session event tap")
            }
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[HotkeyManager] Started monitoring with HID event tap (can override system shortcuts)")
        }
        
        // Also add NSEvent monitor for Globe/Fn key detection (flagsChanged)
        // This can sometimes catch modifier keys that CGEvent misses
        startFnKeyMonitor()
    }
    
    /// Start monitoring for Globe/Fn key using NSEvent
    private func startFnKeyMonitor() {
        // Only monitor if Globe key (179) or Fn key (63) is the configured hotkey
        guard keyCode == 179 || keyCode == 63 else { return }
        
        // Use BOTH global and local monitors to catch the Fn key
        // Global monitor catches events when app is not focused
        fnKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFnKeyEvent(event)
        }
        
        // Also add local monitor for when our app has focus
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFnKeyEvent(event)
            return event
        }
        
        // Store local monitor reference (we'll clean it up with the global one)
        objc_setAssociatedObject(self, "localFnMonitor", localMonitor, .OBJC_ASSOCIATION_RETAIN)
        
        print("[HotkeyManager] Started NSEvent monitors for Globe/Fn key")
    }
    
    private func handleFnKeyEvent(_ event: NSEvent) {
        let fnPressed = event.modifierFlags.contains(.function)
        
        // Only check Fn flag - the Globe key sets the .function modifier
        // Also check that NO other modifiers are pressed (pure Globe key press)
        let otherModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        let hasOtherModifiers = !event.modifierFlags.intersection(otherModifiers).isEmpty
        
        // Log for debugging
        let logMsg = "[HotkeyManager] NSEvent flagsChanged: fn=\(fnPressed), other=\(hasOtherModifiers), keyCode=\(event.keyCode), flags=\(event.modifierFlags.rawValue)\n"
        if let data = logMsg.data(using: .utf8) {
            let fileURL = URL(fileURLWithPath: "/tmp/localwispr_fn.log")
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: fileURL)
            }
        }
        
        // Detect Globe/Fn key press and release (only when no other modifiers)
        if fnPressed && !hasOtherModifiers && !fnKeyWasPressed {
            // Fn key just pressed alone
            fnKeyWasPressed = true
            if !isKeyDown {
                isKeyDown = true
                print("[HotkeyManager] Globe/Fn key DOWN - starting recording")
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyDown?()
                }
            }
        } else if !fnPressed && fnKeyWasPressed {
            // Fn key just released
            fnKeyWasPressed = false
            if isKeyDown {
                isKeyDown = false
                print("[HotkeyManager] Globe/Fn key UP - stopping recording")
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyUp?()
                }
            }
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
        
        if let monitor = fnKeyMonitor {
            NSEvent.removeMonitor(monitor)
            fnKeyMonitor = nil
        }
        
        // Also remove local monitor
        if let localMonitor = objc_getAssociatedObject(self, "localFnMonitor") {
            NSEvent.removeMonitor(localMonitor)
            objc_setAssociatedObject(self, "localFnMonitor", nil, .OBJC_ASSOCIATION_RETAIN)
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
        
        // Debug: Log ALL events to verify the tap is working
        let debugMsg = "Event: type=\(type.rawValue), keyCode=\(currentKeyCode), flags=\(currentFlags.rawValue)\n"
        if let data = debugMsg.data(using: .utf8) {
            let fileURL = URL(fileURLWithPath: "/tmp/localwispr_keys.log")
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: fileURL)
            }
        }
        
        // Debug: Log Fn/Globe key detection (key code 63 or 179)
        // The Globe key on newer Macs can be key code 179 or triggered via Fn (63)
        if currentKeyCode == 63 || currentKeyCode == 179 || currentFlags.contains(.maskSecondaryFn) {
            NSLog("[HotkeyManager] Fn/Globe key detected - keyCode: %d, flags: %llu", currentKeyCode, currentFlags.rawValue)
        }
        
        // Check if our hotkey modifiers are pressed
        let hasRequiredModifiers = checkModifiers(currentFlags)
        
        switch type {
        case .keyDown:
            // Check if this is our hotkey
            if currentKeyCode == keyCode && hasRequiredModifiers {
                if !isKeyDown {
                    hotkeyLogger.info("Hotkey DOWN detected!")
                    isKeyDown = true
                    DispatchQueue.main.async { [weak self] in
                        hotkeyLogger.info("Calling onKeyDown callback")
                        self?.onKeyDown?()
                    }
                }
                return true // Always consume the event to prevent character input
            }
            
        case .keyUp:
            // Check if this is our hotkey key (regardless of modifiers on release)
            if currentKeyCode == keyCode {
                if isKeyDown {
                    hotkeyLogger.info("Hotkey UP detected!")
                    isKeyDown = false
                    DispatchQueue.main.async { [weak self] in
                        hotkeyLogger.info("Calling onKeyUp callback")
                        self?.onKeyUp?()
                    }
                }
                return true // Always consume to prevent any residual character input
            }
            
        case .flagsChanged:
            // Log all flag changes for debugging Globe key
            let logMsg = "[HotkeyManager] Flags changed: rawValue=\(currentFlags.rawValue), keyCode=\(currentKeyCode), hasFn=\(currentFlags.contains(.maskSecondaryFn))"
            print(logMsg)
            NSLog("%@", logMsg)
            hotkeyLogger.debug("Flags changed: \(currentFlags.rawValue), keyCode: \(currentKeyCode)")
            
            // Check if Globe/Fn key is the trigger (no other key, just the modifier)
            // Globe key sets maskSecondaryFn when pressed
            if keyCode == 63 || keyCode == 179 {
                let fnPressed = currentFlags.contains(.maskSecondaryFn)
                if fnPressed && !isKeyDown {
                    hotkeyLogger.info("Globe/Fn key DOWN detected via flagsChanged!")
                    isKeyDown = true
                    DispatchQueue.main.async { [weak self] in
                        self?.onKeyDown?()
                    }
                    return true
                } else if !fnPressed && isKeyDown {
                    hotkeyLogger.info("Globe/Fn key UP detected via flagsChanged!")
                    isKeyDown = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onKeyUp?()
                    }
                    return true
                }
            }
            
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
    
    /// Check if current flags match required modifiers
    private func checkModifiers(_ flags: CGEventFlags) -> Bool {
        // Special case: if no modifiers required (e.g., for function keys or Globe key)
        if modifiers.isEmpty || modifiers == .maskSecondaryFn {
            // For function keys/Globe, we accept with or without Fn modifier
            return true
        }
        
        // Check that all required modifiers are present
        let hasControl = !modifiers.contains(.maskControl) || flags.contains(.maskControl)
        let hasShift = !modifiers.contains(.maskShift) || flags.contains(.maskShift)
        let hasOption = !modifiers.contains(.maskAlternate) || flags.contains(.maskAlternate)
        let hasCommand = !modifiers.contains(.maskCommand) || flags.contains(.maskCommand)
        
        // Also check we don't have extra modifiers we don't want (ignore Fn modifier)
        let flagsWithoutFn = CGEventFlags(rawValue: flags.rawValue & ~CGEventFlags.maskSecondaryFn.rawValue)
        let controlMatch = modifiers.contains(.maskControl) == flagsWithoutFn.contains(.maskControl)
        let shiftMatch = modifiers.contains(.maskShift) == flagsWithoutFn.contains(.maskShift)
        let optionMatch = modifiers.contains(.maskAlternate) == flagsWithoutFn.contains(.maskAlternate)
        let commandMatch = modifiers.contains(.maskCommand) == flagsWithoutFn.contains(.maskCommand)
        
        return hasControl && hasShift && hasOption && hasCommand &&
               controlMatch && shiftMatch && optionMatch && commandMatch
    }
    
    /// Update the hotkey
    func setHotkey(keyCode: UInt16, modifiers: CGEventFlags) {
        let wasGlobeKey = self.keyCode == 179 || self.keyCode == 63
        
        self.keyCode = keyCode
        self.modifiers = modifiers
        
        // Save to UserDefaults
        UserDefaults.standard.set(Int(keyCode), forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(modifiers.rawValue, forKey: "hotkeyModifiers")
        
        // Restart Fn key monitor if switching to/from Globe key
        let isGlobeKey = keyCode == 179 || keyCode == 63
        if wasGlobeKey != isGlobeKey {
            // Stop existing Fn monitor
            if let monitor = fnKeyMonitor {
                NSEvent.removeMonitor(monitor)
                fnKeyMonitor = nil
            }
            if let localMonitor = objc_getAssociatedObject(self, "localFnMonitor") {
                NSEvent.removeMonitor(localMonitor)
                objc_setAssociatedObject(self, "localFnMonitor", nil, .OBJC_ASSOCIATION_RETAIN)
            }
            fnKeyWasPressed = false
            
            // Start new Fn monitor if needed
            if isGlobeKey {
                startFnKeyMonitor()
            }
        }
        
        hotkeyLogger.info("Hotkey updated to: \(self.shortcutString)")
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
        
        if modifiers.contains(.maskSecondaryFn) { parts.append("🌐") }
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
        case 63: keyString = "🌐"  // Globe/Fn key
        case 179: keyString = "🌐"  // Globe key on newer Macs
        case kVK_F1: keyString = "F1"
        case kVK_F2: keyString = "F2"
        case kVK_F3: keyString = "F3"
        case kVK_F4: keyString = "F4"
        case kVK_F5: keyString = "F5"
        case kVK_F6: keyString = "F6"
        case kVK_F7: keyString = "F7"
        case kVK_F8: keyString = "F8"
        case kVK_F9: keyString = "F9"
        case kVK_F10: keyString = "F10"
        case kVK_F11: keyString = "F11"
        case kVK_F12: keyString = "F12"
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
