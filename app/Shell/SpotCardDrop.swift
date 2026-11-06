import AppKit
import SwiftUI

/// The drop target of one card. It reads the dragged files, and marks the card only when the card takes them all.
struct SpotCardDrop: DropDelegate {
    let id: String
    let model: SpotsModel
    @Binding var target: String?

    private var paths: [String] {
        let urls = NSPasteboard(name: .drag).readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        return urls?.map(\.path) ?? []
    }

    func validateDrop(info: DropInfo) -> Bool {
        model.acceptsDrop(paths, on: id)
    }

    func dropEntered(info: DropInfo) {
        if model.acceptsDrop(paths, on: id) { target = id }
    }

    func dropExited(info: DropInfo) {
        if target == id { target = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        target = nil
        return model.drop(paths, on: id)
    }
}
