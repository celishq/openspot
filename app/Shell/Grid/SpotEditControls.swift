import OpenspotCore
import SwiftUI

/// The controls of a card in Edit Spots: the minus that turns the spot off on its top left corner, the eye that puts it on
/// the grid or in search only on its top right corner, and the handle on its bottom right corner that resizes it. The open
/// eye and the handle show while the pointer is over the card; the slashed eye always shows.
struct SpotEditControls: ViewModifier {
    let model: SpotsModel
    let id: String
    let size: SpotSize
    let turnsOff: Bool
    let showsEye: Bool
    let isHidden: Bool
    let isResizable: Bool
    let isResizing: Bool
    /// Whether another card is dragged over the grid, which hides every handle.
    let isDragging: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let showsHandle = isResizing || (isHovered && !isDragging)
        let eyeIsOpen = isHovered && !isDragging
        return content
            .overlay(alignment: .topLeading) {
                if turnsOff {
                    SpotCornerButton(symbol: "minus", label: "Turn Off", corner: .leading, size: size) { model.turnOff(id) }
                }
            }
            .overlay(alignment: .topTrailing) {
                if showsEye {
                    SpotCornerButton(symbol: isHidden ? "eye.slash" : "eye", label: isHidden ? "Show on Grid" : "Hide from Grid", corner: .trailing, size: size) {
                        model.setOnGrid(isHidden, for: id)
                    }
                    .opacity(isHidden || eyeIsOpen ? 1 : 0.001)
                    .animation(SpotMotion.handleFade, value: isHidden || eyeIsOpen)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isResizable {
                    SpotResizeHandle(size: size)
                        .opacity(showsHandle ? 1 : 0.001)
                        .animation(SpotMotion.handleFade, value: showsHandle)
                        .background(SpotHandleArea(model: model, id: id, size: size))
                }
            }
            .onHover { hovering in
                if isHovered != hovering { isHovered = hovering }
            }
    }
}
