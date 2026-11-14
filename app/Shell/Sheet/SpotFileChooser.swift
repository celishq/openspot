import AppKit
import OpenspotCore

@MainActor
final class SpotFileChooser: NSObject, NSOpenSavePanelDelegate {
    private let spot: Spot

    init(spot: Spot) {
        self.spot = spot
    }

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

    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return (values?.isDirectory == true && values?.isPackage != true) || spot.accepts([url.path])
    }
}
