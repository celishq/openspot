import AppKit
import OpenspotCore

/// The system window that chooses files for a card. It enables only what the `drop` of the card takes.
@MainActor
final class SpotFileChooser: NSObject, NSOpenSavePanelDelegate {
    private let spot: Spot

    init(spot: Spot) {
        self.spot = spot
    }

    /// Shows the window, and gives the chosen paths when it closes: none after Cancel.
    func show(onEnd: @escaping ([String]) -> Void) {
        let window = NSOpenPanel()
        window.allowsMultipleSelection = true
        window.canChooseFiles = spot.takesFiles
        window.canChooseDirectories = spot.takesFolders
        window.delegate = self
        window.begin { response in
            onEnd(response == .OK ? window.urls.map(\.path) : [])
        }
    }

    /// A plain folder stays enabled, so that a person can go into it.
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return (values?.isDirectory == true && values?.isPackage != true) || spot.accepts([url.path])
    }
}
