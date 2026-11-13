import AppKit
import Synchronization

/// The bounds of the front window of the app that the person brought forward last, as Core Graphics gives them. It reads
/// them in the background each time an app comes forward on a Mac with two screens or more, so that a press asks the window
/// server nothing.
@MainActor
final class SpotFrontWindow {
    nonisolated private static let queue = DispatchQueue(label: "openspot.front-window", qos: .utility)
    nonisolated private static let kept = Mutex<(pid: pid_t, bounds: CGRect?)?>(nil)
    private var observer: NSObjectProtocol?

    /// Starts to follow the app in front, and reads the window of the one in front now.
    func start() {
        read(NSWorkspace.shared.frontmostApplication)
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.read(app) }
        }
    }

    /// The bounds of the app's front window, or nil when it shows none or another app came forward last.
    func bounds(of app: NSRunningApplication) -> CGRect? {
        Self.kept.withLock { $0?.pid == app.processIdentifier ? $0?.bounds : nil }
    }

    private func read(_ app: NSRunningApplication?) {
        guard let app, app != .current, NSScreen.screens.count > 1 else { return }
        let pid = app.processIdentifier
        Self.queue.async {
            let bounds = Self.frontWindow(of: pid)
            Self.kept.withLock { $0 = (pid, bounds) }
        }
    }

    /// The bounds of the front window of a process, or nil when it shows none. They need no permission.
    nonisolated private static func frontWindow(of pid: pid_t) -> CGRect? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let front = windows.first {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        return (front?[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
    }
}
