import AppKit
import OpenspotCore

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
        return SpotPackage.isFile(SpotGridDrop.paths) ? .copy : []
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let paths = SpotGridDrop.paths
        guard SpotPackage.isFile(paths) else { return false }
        onDrop(paths.map { URL(fileURLWithPath: $0) })
        return true
    }
}
