import OpenspotCore
import SwiftUI

struct SpotFailureTip: ViewModifier {
    let model: SpotsModel
    let id: String
    let text: String

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .onHover { isOver in
                            if isOver {
                                model.tip = SpotTip(id: id, anchor: .below(proxy.frame(in: .named(SpotsView.panelSpace))), text: text)
                            } else if model.tip?.id == id {
                                model.tip = nil
                            }
                        }
                }
            }
            .onDisappear { if model.tip?.id == id { model.tip = nil } }
    }
}
