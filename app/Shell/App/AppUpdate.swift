import AppKit
@preconcurrency import Sparkle
import OpenspotCore

@MainActor
final class AppUpdate: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private(set) var readyVersion: String?
    private var controller: SPUStandardUpdaterController?
    private var install: (() -> Void)?
    private var showsWindow = false
    private let onReady: @MainActor (String) -> Void

    init?(onReady: @escaping @MainActor (String) -> Void) {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !key.isEmpty else { return nil }
        self.onReady = onReady
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    }

    func start() {
        controller?.startUpdater()
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
            readyVersion = version
            onReady(version)
        }
        return true
    }

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
        start()
        controller?.checkForUpdates(nil)
    }

    @discardableResult
    func restart() -> Bool {
        guard let install else { return false }
        install()
        return true
    }
}
