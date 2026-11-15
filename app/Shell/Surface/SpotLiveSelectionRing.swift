import SwiftUI

struct SpotLiveSelectionRing<Edge: InsettableShape>: ViewModifier {
    let isSelected: () -> Bool
    let shape: Edge
    var progress: Double?
    var marksMenu = false

    func body(content: Content) -> some View {
        content.modifier(SpotSelectionRing(isSelected: isSelected(), shape: shape, progress: progress, marksMenu: marksMenu))
    }
}
