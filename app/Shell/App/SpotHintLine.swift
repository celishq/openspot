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
        let open = max(sheetHeight + model.flowEdges.heldHeight(of: sheetRect), menuHeight)
        let closed = surfaceIsOut && progress == 0 ? open : gridHeight
        ZStack(alignment: .top) {
            hint(model.gridHint, isShown: !surfaceIsOut)
            hint(sheetWords, isShown: surfaceIsOut)
        }
        .modifier(FootPlace(closed: closed, open: open, isOut: surfaceIsOut, morph: morph, progress: progress))
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
    var closed: CGFloat
    var open: CGFloat
    let isOut: Bool
    let morph: SheetMorph?
    var progress: Double

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, Double> {
        get { AnimatablePair(AnimatablePair(closed, open), progress) }
        set {
            closed = newValue.first.first
            open = newValue.first.second
            progress = newValue.second
        }
    }

    func body(content: Content) -> some View {
        let foot = morph.map { $0.blurFoot(over: SheetPush.Foot(closed: closed, open: open), at: progress) } ?? (isOut ? open : closed)
        content.offset(y: foot - SpotTokens.halo - SpotTokens.hintPillHeight)
    }
}
