import AppKit
@preconcurrency import Sparkle
import OpenspotCore

/// Keeps the app current: it checks GitHub each day, downloads a new version silently and installs it on quit, or at once
/// from the Updates spot. A build with no update key has none of this.
@MainActor
final class AppUpdate: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private(set) var spot: UpdateSpot!
    /// The version of the downloaded update that waits to install.
    private(set) var ready: String?
    private var controller: SPUStandardUpdaterController?
    private var install: (() -> Void)?
    private let onReady: @MainActor () -> Void

    init?(runningWork: @escaping @MainActor () -> Int, onReady: @escaping @MainActor () -> Void) {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !key.isEmpty else { return nil }
        self.onReady = onReady
        super.init()
        spot = UpdateSpot(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            runningWork: { await runningWork() },
            check: { [weak self] in await self?.check() },
            restart: { [weak self] in await self?.restart() }
        )
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
            Task {
                await spot.take(ready: version)
                onReady()
            }
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
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated {
            _ = NSApp.setActivationPolicy(.accessory)
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
