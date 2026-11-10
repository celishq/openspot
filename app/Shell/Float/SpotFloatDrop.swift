import AppKit
import OpenspotCore
import SwiftUI

/// The drop target of a float. While a drag of files that its spot takes lies over it, it says what the drop adds (W9).
struct SpotFloatDrop: DropDelegate {
    let id: String
    let model: SpotsModel
    @Binding var words: String?

    func validateDrop(info: DropInfo) -> Bool {
        model.floatAccepts(SpotCardDrop.paths, of: id)
    }

    func dropEntered(info: DropInfo) {
        let paths = SpotCardDrop.paths
        guard model.floatAccepts(paths, of: id) else { return }
        words = paths.count == 1 ? "Add \(URL(fileURLWithPath: paths[0]).lastPathComponent)" : "Add \(paths.count) files"
    }

    func dropExited(info: DropInfo) {
        words = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        words = nil
        return model.dropOnFloat(SpotCardDrop.paths, of: id)
    }
}
