import AppKit
import SwiftUI

/// The drop target of one card. It reads the dragged files, and says which card is under a drag that it takes.
struct SpotCardDrop: DropDelegate {
    let id: String
    let model: SpotsModel
    @Binding var target: String?

    /// The files of the drag in progress.
    static var paths: [String] {
        let urls = NSPasteboard(name: .drag).readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        return urls?.map(\.path) ?? []
    }

    func validateDrop(info: DropInfo) -> Bool {
        model.followDrag()
        return model.acceptsDrop(Self.paths, on: id)
    }

    func dropEntered(info: DropInfo) {
        if model.acceptsDrop(Self.paths, on: id) { target = id }
    }

    func dropExited(info: DropInfo) {
        if target == id { target = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        target = nil
        return model.drop(Self.paths, on: id)
    }
}
