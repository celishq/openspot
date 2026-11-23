import OpenspotCore
import SwiftUI

struct SpotGridCard: View, @MainActor Equatable {
    let entry: SpotsModel.Entry
    let size: SpotSize
    let index: Int
    let isHeld: Bool
    let takesDrag: Bool
    let isDropTarget: Bool
    let model: SpotsModel
    @GestureState private var isPressed = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry && lhs.size == rhs.size && lhs.index == rhs.index && lhs.isHeld == rhs.isHeld
            && lhs.takesDrag == rhs.takesDrag && lhs.isDropTarget == rhs.isDropTarget
            && lhs.model === rhs.model
    }

    var body: some View {
        if entry.role == .preview {
            SpotContextPreview(entry: entry, size: size)
        } else {
            card
        }
    }

    private var card: some View {
        SpotCardView(
            entry: entry,
            size: size,
            index: index,
            isPressed: isPressed && !isHeld,
            takesDrag: takesDrag,
            isDropTarget: isDropTarget,
            model: model
        )
        .equatable()
        .simultaneousGesture(DragGesture(minimumDistance: 0).updating($isPressed) { _, isPressed, _ in isPressed = true })
    }
}
