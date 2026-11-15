import AppKit
import OpenspotCore
import SwiftUI

struct SpotFloatDrop: DropDelegate {
    let id: String
    let place: SheetPlace
    let model: SpotsModel
    @Binding var target: String?

    func validateDrop(info: DropInfo) -> Bool {
        model.followDrag()
        return !model.dragPaths.isEmpty
    }

    func dropEntered(info: DropInfo) {
        _ = dropUpdated(info: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let takes = model.acceptsDrop(model.dragPaths, on: id, in: place)
        let next = takes ? id : target == id ? nil : target
        if target != next { target = next }
        return DropProposal(operation: takes ? .copy : .forbidden)
    }

    func dropExited(info: DropInfo) {
        if target == id { target = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        target = nil
        return model.drop(SpotGridDrop.paths, on: id, in: place)
    }
}
