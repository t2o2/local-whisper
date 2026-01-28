import SwiftUI

@main
struct LocalWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Pure menu bar app - no windows on launch
        // Settings window is managed by AppDelegate.showSettings()
        MenuBarExtra {
            // Empty - we use our custom popover from AppDelegate instead
            EmptyView()
        } label: {
            // Empty - we use our custom status item from AppDelegate instead
            EmptyView()
        }
        .menuBarExtraStyle(.window)
    }
}
