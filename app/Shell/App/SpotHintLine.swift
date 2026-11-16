import OpenspotCore
import SwiftUI

struct SpotHintLine: View {
    let model: SpotsModel
    let surfaceIsOut: Bool
    let gridHeight: CGFloat
    let sheetHeight: CGFloat
    let sheetRect: CGRect
    let menuHeight: CGFloat

    var body: some View {
        let height = surfaceIsOut ? max(sheetHeight + model.flowEdges.heldHeight(of: sheetRect), menuHeight) : gridHeight
        ZStack(alignment: .top) {
            hint(model.gridHint, isShown: !surfaceIsOut, height: height)
            hint(sheetWords, isShown: surfaceIsOut, height: height)
        }
        .onAppear { model.followHint() }
    }

    private func hint(_ words: HintWords, isShown: Bool, height: CGFloat) -> some View {
        ZStack {
            ForEach([words], id: \.self) { words in
                SpotHint(words: words, activeKey: model.isMenuOpen ? ActionMenu.key : nil, onPress: model.pressHint)
                    .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.panelWidth)
        .allowsHitTesting(isShown)
        .offset(y: height - SpotTokens.halo - SpotTokens.hintPillHeight)
        .morph(isShown ? 1 : 0, opacity: { SheetMorph.sheetLook(at: $0) })
    }

    private var sheetWords: HintWords {
        model.formRect == nil ? model.sheetHint : model.formHint
    }
}
