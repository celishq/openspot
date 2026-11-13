import OpenspotCore
import SwiftUI

/// Lets a person drag the files of these rows out of a sheet (protocol: Files out). It adds nothing when no row has a file,
/// and finds the rows with files only when a drag starts.
struct SpotFileDragSource: ViewModifier {
    let items: [SpotItem]
    /// Whether a row has a file, which the list knows without a pass over its rows.
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
