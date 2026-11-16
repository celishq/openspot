import OpenspotCore
import SwiftUI

struct SpotHintLine: View {
    let model: SpotsModel
    let surfaceIsOut: Bool
    let gridHeight: CGFloat
    let sheetHeight: CGFloat
    let sheetRect: CGRect
    let menuHeight: CGFloat
    let morph: SheetMorph?
    let progress: Double

    var body: some View {
        let height = surfaceIsOut ? max(sheetHeight + model.flowEdges.heldHeight(of: sheetRect), menuHeight) : gridHeight
        ZStack(alignment: .top) {
            hint(model.gridHint, isShown: !surfaceIsOut)
            hint(sheetWords, isShown: surfaceIsOut)
        }
        .modifier(FootPlace(height: height, morph: morph, progress: progress))
        .onAppear { model.followHint() }
    }

    private func hint(_ words: HintWords, isShown: Bool) -> some View {
        ZStack {
            ForEach([words], id: \.self) { words in
                SpotHint(words: words, activeKey: model.isMenuOpen ? ActionMenu.key : nil, onPress: model.pressHint)
                    .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.panelWidth)
        .allowsHitTesting(isShown)
        .morph(isShown ? 1 : 0, opacity: { SheetMorph.sheetLook(at: $0) })
    }

    private var sheetWords: HintWords {
        model.formRect == nil ? model.sheetHint : model.formHint
    }
}

private struct FootPlace: ViewModifier, @preconcurrency Animatable {
    var height: CGFloat
    let morph: SheetMorph?
    var progress: Double

    var animatableData: AnimatablePair<CGFloat, Double> {
        get { AnimatablePair(height, progress) }
        set {
            height = newValue.first
            progress = newValue.second
        }
    }

    func body(content: Content) -> some View {
        let foot = morph.map { max(height, $0.foot(at: progress)) } ?? height
        content.offset(y: foot - SpotTokens.halo - SpotTokens.hintPillHeight)
    }
}
