import AppKit
@preconcurrency import Sparkle
import OpenspotCore

/// Keeps the app current: it checks GitHub each day, downloads a new version silently and installs it on quit, or at once
/// from the Updates spot. A build with no update key has none of this.
@MainActor
final class AppUpdate: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    /// The version of the downloaded update that waits to install.
    private(set) var ready: String?
    private var controller: SPUStandardUpdaterController?
    private var install: (() -> Void)?
    /// Whether Sparkle shows its window now, which keeps the app in the Dock.
    private var showsWindow = false
    private let onReady: @MainActor (String) -> Void

    init?(onReady: @escaping @MainActor (String) -> Void) {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !key.isEmpty else { return nil }
        self.onReady = onReady
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
    }

    nonisolated var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        let version = item.displayVersionString
        nonisolated(unsafe) let handler = immediateInstallHandler
        MainActor.assumeIsolated {
            install = handler
            ready = version
            onReady(version)
        }
        return true
    }

    /// Brings the app to the front while Sparkle shows its update window.
    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard handleShowingUpdate else { return }
        MainActor.assumeIsolated {
            guard !showsWindow else { return }
            showsWindow = true
            AppPresence.open()
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated {
            guard showsWindow else { return }
            showsWindow = false
            AppPresence.close()
        }
    }

    func check() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    /// Restarts into the downloaded update, and returns false when none waits.
    @discardableResult
    func restart() -> Bool {
        guard let install else { return false }
        install()
        return true
    }
}
