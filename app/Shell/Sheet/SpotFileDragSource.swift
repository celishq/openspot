import OpenspotCore
import SwiftUI

/// Lets a person drag the files of these rows out of a sheet (O1, O3). It adds nothing when no row has a file.
struct SpotFileDragSource: ViewModifier {
    let items: [SpotItem]
    let onDrop: ([SpotItem]) -> Void
    @State private var isDragging = false

    func body(content: Content) -> some View {
        let carried = items.filter { $0.carriedFile != nil }
        if carried.isEmpty {
            content
        } else {
            content.simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { _ in
                guard !isDragging else { return }
                isDragging = SpotFileDrag.begin(carried.compactMap(\.carriedFile), onDrop: { onDrop(carried) }, onEnd: { isDragging = false })
            })
        }
    }
}
