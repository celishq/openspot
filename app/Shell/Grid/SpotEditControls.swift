import OpenspotCore
import SwiftUI

struct SpotEditControls: ViewModifier {
    let model: SpotsModel
    let id: String
    let size: SpotSize
    let takesOffGrid: Bool
    let sizes: [SpotSize]
    let isResizing: Bool
    let isDragging: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                if takesOffGrid {
                    SpotCornerButton(symbol: "minus", label: "Take off the grid", corner: .leading, size: size, onHover: tip(.leadingCorner, text: "Take off the grid")) {
                        model.takeOffGrid(id)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if sizes.count > 1 {
                    PointedHandle(model: model, id: id, size: size, sizes: sizes, isResizing: isResizing, isDragging: isDragging)
                }
            }
            .onDisappear { if model.tip?.id == id { model.tip = nil } }
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

private struct PointedHandle: View {
    let model: SpotsModel
    let id: String
    let size: SpotSize
    let sizes: [SpotSize]
    let isResizing: Bool
    let isDragging: Bool

    var body: some View {
        let showsHandle = isResizing || (model.pointedCard == id && !isDragging)
        SpotResizeHandle(size: size)
            .opacity(showsHandle ? 1 : MotionTokens.hiddenOpacity)
            .animation(SpotMotion.fade(isShown: showsHandle), value: showsHandle)
            .background(SpotHandleArea(model: model, id: id, size: size, sizes: sizes))
    }
}
