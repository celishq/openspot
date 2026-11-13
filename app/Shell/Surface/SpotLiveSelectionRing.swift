import SwiftUI

/// The selection ring of an item that reads whether it is selected itself, where it draws, so that a move of the
/// selection reruns only the rings and no item.
struct SpotLiveSelectionRing<Edge: InsettableShape>: ViewModifier {
    let isSelected: () -> Bool
    let shape: Edge
    var progress: Double?
    var marksMenu = false

    func body(content: Content) -> some View {
        content.modifier(SpotSelectionRing(isSelected: isSelected(), shape: shape, progress: progress, marksMenu: marksMenu))
    }
}
