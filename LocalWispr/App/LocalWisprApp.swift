import SwiftUI
import KeyboardShortcuts

@main
struct LocalWisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        // Menu bar app - no window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
