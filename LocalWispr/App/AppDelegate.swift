import AppKit
import SwiftUI
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let appState = AppState.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBar()
        setupGlobalShortcut()
        
        Task {
            await initializeServices()
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "LocalWispr")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appState)
        )
    }
    
    private func setupGlobalShortcut() {
        // Register default shortcut if not set
        if KeyboardShortcuts.getShortcut(for: .toggleRecording) == nil {
            KeyboardShortcuts.setShortcut(.init(.space, modifiers: [.command, .shift]), for: .toggleRecording)
        }
        
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                await self?.appState.coordinator.handleHotkeyPressed()
            }
        }
        
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                await self?.appState.coordinator.handleHotkeyReleased()
            }
        }
    }
    
    private func initializeServices() async {
        // Check permissions first
        await appState.permissionsService.checkAllPermissions()
        
        // Load whisper model in background
        if appState.permissionsService.microphoneGranted {
            await appState.transcriptionService.loadModel()
        }
    }
    
    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func updateStatusIcon(for state: TranscriptionState) {
        guard let button = statusItem?.button else { return }
        
        let iconName: String
        switch state {
        case .idle:
            iconName = "waveform"
        case .recording:
            iconName = "mic.fill"
        case .transcribing:
            iconName = "ellipsis.circle"
        case .error:
            iconName = "exclamationmark.triangle"
        }
        
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "LocalWispr - \(state)")
    }
}

// MARK: - Keyboard Shortcuts Extension
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
}
