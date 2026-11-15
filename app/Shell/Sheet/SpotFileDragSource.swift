import OpenspotCore
import SwiftUI

struct SpotFileDragSource: ViewModifier {
    let items: [SpotItem]
    let hasFiles: Bool
    let onDrop: ([SpotItem]) -> Void
    @State private var isDragging = false

    func body(content: Content) -> some View {
        if hasFiles {
            content.simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { _ in
                guard !isDragging else { return }
                let carried = items.filter { $0.file != nil }
                isDragging = SpotFileDrag.begin(carried.compactMap(\.file), onDrop: { onDrop(carried) }, onEnd: { isDragging = false })
            })
        } else {
            content
        }
    }
}
