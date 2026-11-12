import AppKit
import OpenspotCore

/// A drag of files over the Openspot item in the menu bar. It tells its owner when the drag enters, and the item takes only a
/// drop of `.spot` files.
@MainActor
final class SpotMenuBarDrag: NSObject, NSWindowDelegate, NSDraggingDestination {
    private let onEnter: () -> Void
    private let onDrop: ([URL]) -> Void

    init(button: NSStatusBarButton, onEnter: @escaping () -> Void, onDrop: @escaping ([URL]) -> Void) {
        self.onEnter = onEnter
        self.onDrop = onDrop
        super.init()
        button.window?.registerForDraggedTypes([.fileURL])
        button.window?.delegate = self
    }

    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        onEnter()
        return SpotFolder.isFile(SpotGridDrop.paths) ? .copy : []
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let paths = SpotGridDrop.paths
        guard SpotFolder.isFile(paths) else { return false }
        onDrop(paths.map { URL(fileURLWithPath: $0) })
        return true
    }
}
