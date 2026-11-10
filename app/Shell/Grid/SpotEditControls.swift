import OpenspotCore
import SwiftUI

/// The controls of a card in Edit Spots: the minus, or the plus of a hidden card, on its top left corner, and the handle on
/// its bottom right corner that resizes it. The handle shows while the pointer is over the card, and while it resizes.
struct SpotEditControls: ViewModifier {
    let model: SpotsModel
    let id: String
    let size: SpotSize
    let showsHide: Bool
    let isHidden: Bool
    let isResizable: Bool
    let isResizing: Bool
    /// Whether another card is dragged over the grid, which hides every handle.
    let isDragging: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let showsHandle = isResizing || (isHovered && !isDragging)
        return content
            .overlay(alignment: .topLeading) {
                if showsHide {
                    SpotHideButton(model: model, id: id, isHidden: isHidden, size: size)
                }
            }
            .overlay {
                if isResizable {
                    SpotResizeHandle(size: size)
                        .opacity(showsHandle ? 1 : 0.001)
                        .animation(SpotMotion.handleFade, value: showsHandle)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isResizable {
                    Color.clear
                        .frame(width: SpotTokens.resizeHandle, height: SpotTokens.resizeHandle)
                        .contentShape(Rectangle())
                        .gesture(resizeGesture)
                }
            }
            .onHover { hovering in
                if isHovered != hovering { isHovered = hovering }
            }
    }

    /// Resizes the card by its handle: it snaps to the nearest size, and the other cards make room.
    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(SpotsView.panelSpace))
            .onChanged { model.resizeSpot(id, by: $0.translation) }
            .onEnded { _ in model.dropResize() }
    }
}
