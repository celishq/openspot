import OpenspotCore
import SwiftUI

struct SpotEditControls: ViewModifier {
    let model: SpotsModel
    let id: String
    let size: SpotSize
    let turnsOff: Bool
    let sizes: [SpotSize]
    let isResizing: Bool
    let isDragging: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let showsHandle = isResizing || (isHovered && !isDragging)
        return content
            .overlay(alignment: .topLeading) {
                if turnsOff {
                    SpotCornerButton(symbol: "minus", label: "Turn off", corner: .leading, size: size, onHover: tip(.leadingCorner, text: "Turn off")) {
                        model.turnOff(id)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if sizes.count > 1 {
                    SpotResizeHandle(size: size)
                        .opacity(showsHandle ? 1 : 0.001)
                        .animation(SpotMotion.fade(isShown: showsHandle), value: showsHandle)
                        .background(SpotHandleArea(model: model, id: id, size: size, sizes: sizes))
                }
            }
            .onDisappear { if model.tip?.id == id { model.tip = nil } }
            .onHover { hovering in
                if isHovered != hovering { isHovered = hovering }
            }
    }

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
