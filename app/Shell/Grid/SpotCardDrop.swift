import AppKit
import OpenspotCore
import SwiftUI

/// The drop target of one card or one float. It reads the dragged files, and says which spot is under a drag that it takes.
/// A `.spot` file goes to the review on any card.
struct SpotCardDrop: DropDelegate {
    let id: String
    let model: SpotsModel
    @Binding var target: String?
    var place = SheetPlace.panel

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
        guard place == .panel else { return model.acceptsDrop(Self.paths, on: id, in: place) }
        model.followDrag()
        return SharedSpot.isFile(Self.paths) || model.acceptsDrop(Self.paths, on: id)
    }

    func dropEntered(info: DropInfo) {
        if model.acceptsDrop(Self.paths, on: id, in: place) { target = id }
    }

    func dropExited(info: DropInfo) {
        if target == id { target = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        target = nil
        if place == .panel, SharedSpot.isFile(Self.paths) {
            model.review(Self.paths.map { URL(fileURLWithPath: $0) })
            return true
        }
        return model.drop(Self.paths, on: id, in: place)
    }
}
