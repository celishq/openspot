import AppKit
import OpenspotCore
import SwiftUI

/// The one drop target of the grid. It finds the card under a drag, reads the dragged files, and says which card takes them.
/// A `.spot` file goes to the review on any card.
struct SpotCardDrop: DropDelegate {
    let model: SpotsModel
    @Binding var target: String?

    /// The files of the drag in progress.
    static var paths: [String] {
        paths(on: NSPasteboard(name: .drag))
    }

    /// The files that a pasteboard holds.
    static func paths(on pasteboard: NSPasteboard) -> [String] {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        return urls?.map(\.path) ?? []
    }

    func validateDrop(info: DropInfo) -> Bool {
        model.followDrag()
        let paths = Self.paths
        return SharedSpot.isFile(paths) || model.visible.contains { model.acceptsDrop(paths, on: $0.id) }
    }

    func dropEntered(info: DropInfo) {
        _ = dropUpdated(info: info)
    }

    /// Marks the card under the drag when it takes the files, and lets the drop through only over a card that takes them.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let id = model.card(at: info.location)
        let taker = id.flatMap { model.takesDrag($0) ? $0 : nil }
        if target != taker { target = taker }
        let isSpot = id != nil && SharedSpot.isFile(model.dragPaths)
        return DropProposal(operation: taker != nil || isSpot ? .copy : .forbidden)
    }

    func dropExited(info: DropInfo) {
        target = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        target = nil
        guard let id = model.card(at: info.location) else { return false }
        if SharedSpot.isFile(Self.paths) {
            model.review(Self.paths.map { URL(fileURLWithPath: $0) })
            return true
        }
        return model.drop(Self.paths, on: id)
    }
}
