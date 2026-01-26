import SwiftUI

@main
struct LocalWisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        // Settings window only - menu bar is handled by AppDelegate
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
