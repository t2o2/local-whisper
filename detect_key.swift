#!/usr/bin/env swift

import Cocoa
import Carbon.HIToolbox

print("=== Key Detection Tool ===")
print("Press any key to see its keyCode and modifiers.")
print("Press Ctrl+C to exit.\n")
print("Make sure to grant Accessibility permission to Terminal if prompted.\n")

// Check accessibility
if !AXIsProcessTrusted() {
    print("⚠️  Accessibility permission not granted!")
    print("Go to: System Settings → Privacy & Security → Accessibility")
    print("Add Terminal (or your terminal app) to the list.\n")
}

// Create event tap
let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                              (1 << CGEventType.keyUp.rawValue) |
                              (1 << CGEventType.flagsChanged.rawValue)

let callback: CGEventTapCallBack = { proxy, type, event, refcon in
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    
    var modifiers: [String] = []
    if flags.contains(.maskCommand) { modifiers.append("⌘") }
    if flags.contains(.maskShift) { modifiers.append("⇧") }
    if flags.contains(.maskControl) { modifiers.append("⌃") }
    if flags.contains(.maskAlternate) { modifiers.append("⌥") }
    if flags.contains(.maskSecondaryFn) { modifiers.append("fn") }
    
    let modStr = modifiers.isEmpty ? "none" : modifiers.joined(separator: "+")
    
    switch type {
    case .keyDown:
        print("⬇️  KeyDown:  keyCode=\(keyCode) (0x\(String(keyCode, radix: 16))), modifiers=\(modStr), rawFlags=\(flags.rawValue)")
    case .keyUp:
        print("⬆️  KeyUp:    keyCode=\(keyCode) (0x\(String(keyCode, radix: 16))), modifiers=\(modStr)")
    case .flagsChanged:
        print("🚩 Flags:    keyCode=\(keyCode) (0x\(String(keyCode, radix: 16))), modifiers=\(modStr), rawFlags=\(flags.rawValue)")
    default:
        break
    }
    
    return Unmanaged.passRetained(event)
}

guard let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: eventMask,
    callback: callback,
    userInfo: nil
) else {
    print("❌ Failed to create event tap. Make sure Accessibility is enabled.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

print("✅ Listening for key events... Press any key!\n")

// Also add NSEvent monitor for flagsChanged (might catch Globe/Fn better)
let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
    let fnPressed = event.modifierFlags.contains(.function)
    print("🔔 NSEvent flagsChanged: fn=\(fnPressed), keyCode=\(event.keyCode), rawFlags=\(event.modifierFlags.rawValue)")
}

CFRunLoopRun()
