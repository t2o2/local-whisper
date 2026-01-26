import Foundation
import Sparkle

/// Manages application updates using Sparkle framework
@MainActor
final class UpdaterService: NSObject, ObservableObject {
    /// The Sparkle updater controller
    private var updaterController: SPUStandardUpdaterController!
    
    /// Whether automatic update checks are enabled
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }
    
    /// The last time updates were checked
    @Published var lastUpdateCheckDate: Date?
    
    /// Whether an update is currently being checked
    @Published var isCheckingForUpdates: Bool = false
    
    override init() {
        // Initialize with default value before super.init
        self.automaticallyChecksForUpdates = true
        
        super.init()
        
        // Initialize Sparkle updater controller
        // The second parameter controls whether to start the updater automatically
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Sync the published property with actual updater state
        automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
        lastUpdateCheckDate = updaterController.updater.lastUpdateCheckDate
    }
    
    /// Check for updates manually
    func checkForUpdates() {
        isCheckingForUpdates = true
        updaterController.checkForUpdates(nil)
        
        // Update the last check date after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.lastUpdateCheckDate = self?.updaterController.updater.lastUpdateCheckDate
            self?.isCheckingForUpdates = false
        }
    }
    
    /// Whether the updater can check for updates
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
}
