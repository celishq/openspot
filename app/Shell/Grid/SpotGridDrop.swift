import AppKit
import OpenspotCore
import SwiftUI

/// The one drop target of the grid. It finds the card under a drag, reads the dragged files, and says which card takes them.
/// A `.spot` file goes to the review on any card, and a card of the store adds its spot where it lands.
struct SpotGridDrop: DropDelegate {
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

    /// The store ID of a card of the store that the drag in progress carries.
    static var storeID: String? {
        SpotCardSource.storeID(in: NSPasteboard(name: .drag).string(forType: .string))
    }

    func validateDrop(info: DropInfo) -> Bool {
        if Self.storeID != nil { return model.isEditing }
        model.followDrag()
        let paths = Self.paths
        return SpotPackage.isFile(paths) || model.visible.contains { model.acceptsDrop(paths, on: $0.id) }
    }

    func dropEntered(info: DropInfo) {
        _ = dropUpdated(info: info)
    }

    /// Marks the card under the drag when it takes the files. It lets a `.spot` file through anywhere, and other files only over
    /// a card that takes them.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        if Self.storeID != nil { return DropProposal(operation: .copy) }
        let taker = model.card(at: info.location).flatMap { model.takesDrag($0) ? $0 : nil }
        if target != taker { target = taker }
        return DropProposal(operation: taker != nil || SpotPackage.isFile(model.dragPaths) ? .copy : .forbidden)
    }

    func dropExited(info: DropInfo) {
        target = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        target = nil
        if let id = Self.storeID { return model.dropStoreSpot(id, at: info.location) }
        let paths = Self.paths
        if SpotPackage.isFile(paths) {
            model.review(paths.map { URL(fileURLWithPath: $0) })
            return true
        }
        guard let id = model.card(at: info.location) else { return false }
        return model.drop(paths, on: id)
    }
}
