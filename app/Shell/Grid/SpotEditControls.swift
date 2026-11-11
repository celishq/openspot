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
    /// The sizes that the handle offers. With fewer than two the card shows no handle.
    let sizes: [SpotSize]
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
                    SpotCornerButton(symbol: "minus", label: "Turn off", corner: .leading, size: size, onHover: tip(.leadingCorner, text: "Turn off")) {
                        model.turnOff(id)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if showsEye {
                    let label = isHidden ? "Show on grid" : "Hide from grid"
                    SpotCornerButton(symbol: isHidden ? "eye.slash" : "eye", label: label, corner: .trailing, size: size, onHover: tip(.trailingCorner, text: label)) {
                        model.setOnGrid(isHidden, for: id)
                    }
                    .opacity(isHidden || eyeIsOpen ? 1 : 0.001)
                    .animation(SpotMotion.handleFade, value: isHidden || eyeIsOpen)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if sizes.count > 1 {
                    SpotResizeHandle(size: size)
                        .opacity(showsHandle ? 1 : 0.001)
                        .animation(SpotMotion.handleFade, value: showsHandle)
                        .background(SpotHandleArea(model: model, id: id, size: size, sizes: sizes))
                }
            }
            .onDisappear { if model.tip?.id == id { model.tip = nil } }
            .onHover { hovering in
                if isHovered != hovering { isHovered = hovering }
            }
    }

    /// Shows the tip of a corner control while the pointer lies over it.
    private func tip(_ anchor: SpotTip.Anchor, text: String) -> (Bool) -> Void {
        let tip = SpotTip(id: id, anchor: anchor, text: text)
        return { isOver in
            if isOver {
                model.tip = tip
            } else if model.tip == tip {
                model.tip = nil
            }
        }
    }
}
