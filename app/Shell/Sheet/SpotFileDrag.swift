import AppKit
import OpenspotCore

/// A drag of the files of rows out of a sheet, as a drag out of Finder: the app that takes the drop copies or moves them
/// (O1). When the drop ends in another app, it tells its owner (O2). A drop on Openspot, such as back on its own shelf,
/// tells it nothing.
@MainActor
final class SpotFileDrag: NSObject, NSDraggingSource {
    private static let iconSide: CGFloat = 32
    private static let fan: CGFloat = 6
    /// The drag in progress, which AppKit holds only weakly.
    private static var current: SpotFileDrag?

    private let onDrop: () -> Void
    private let onEnd: () -> Void

    private init(onDrop: @escaping () -> Void, onEnd: @escaping () -> Void) {
        self.onDrop = onDrop
        self.onEnd = onEnd
    }

    /// Starts a drag of the files that these paths name, from the press that the app handles now. A file that does not exist
    /// drags nothing. Returns false when no drag starts.
    @discardableResult
    static func begin(_ paths: [String], onDrop: @escaping () -> Void, onEnd: @escaping () -> Void) -> Bool {
        let existing = paths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existing.isEmpty, let event = NSApp.currentEvent, let view = event.window?.contentView else { return false }
        let point = view.convert(event.locationInWindow, from: nil)
        let items = existing.enumerated().map { index, path in
            let item = NSDraggingItem(pasteboardWriter: URL(fileURLWithPath: path) as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: path)
            let shift = CGFloat(min(index, 3)) * fan
            item.setDraggingFrame(NSRect(x: point.x - iconSide / 2 + shift, y: point.y - iconSide / 2 - shift, width: iconSide, height: iconSide), contents: icon)
            return item
        }
        let drag = SpotFileDrag(onDrop: onDrop, onEnd: onEnd)
        current = drag
        view.beginDraggingSession(with: items, event: event, source: drag)
        return true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let isOwn = (NSApp.delegate as? OpenspotApp)?.takesDrop(at: screenPoint) == true
        if !operation.isEmpty, !isOwn { onDrop() }
        onEnd()
        Self.current = nil
    }
}
