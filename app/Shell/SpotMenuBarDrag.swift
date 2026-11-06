import AppKit

/// A drag of files over the Openspot item in the menu bar. It tells its owner when the drag enters, and the item takes no drop.
@MainActor
final class SpotMenuBarDrag: NSObject, NSWindowDelegate, NSDraggingDestination {
    private let onEnter: () -> Void

    init(button: NSStatusBarButton, onEnter: @escaping () -> Void) {
        self.onEnter = onEnter
        super.init()
        button.window?.registerForDraggedTypes([.fileURL])
        button.window?.delegate = self
    }

    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        onEnter()
        return []
    }
}
