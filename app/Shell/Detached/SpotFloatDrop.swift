import AppKit
import OpenspotCore
import SwiftUI

/// The drop target of a float. It reads the dragged files, and says whether the spot of the float takes them.
struct SpotFloatDrop: DropDelegate {
    let id: String
    let place: SheetPlace
    let model: SpotsModel
    @Binding var target: String?

    func validateDrop(info: DropInfo) -> Bool {
        model.acceptsDrop(SpotGridDrop.paths, on: id, in: place)
    }

    func dropEntered(info: DropInfo) {
        if model.acceptsDrop(SpotGridDrop.paths, on: id, in: place) { target = id }
    }

    func dropExited(info: DropInfo) {
        if target == id { target = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        target = nil
        return model.drop(SpotGridDrop.paths, on: id, in: place)
    }
}
