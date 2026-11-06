import AppKit
import Sparkle

/// Keeps the app current: it checks GitHub each day, downloads a new version silently and installs it on quit.
/// A Debug build never checks.
@MainActor
final class AppUpdate: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        #if DEBUG
        let starts = false
        #else
        let starts = true
        #endif
        controller = SPUStandardUpdaterController(startingUpdater: starts, updaterDelegate: self, userDriverDelegate: self)
    }

    nonisolated var supportsGentleScheduledUpdateReminders: Bool {
        true
    }
}
