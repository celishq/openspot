import OpenspotCore
import SwiftUI

struct SpotHintLine: View {
    let model: SpotsModel
    let surfaceIsOut: Bool
    let motion: SheetMotion

    var body: some View {
        ZStack(alignment: .top) {
            hint(model.gridHint, isShown: !surfaceIsOut)
            hint(sheetWords, isShown: surfaceIsOut)
        }
        .modifier(FootOffset(foot: foot, motion: motion, inset: SpotTokens.halo + SpotTokens.hintPillHeight))
        .onAppear { model.followHint() }
    }

    private var foot: PanelFoot {
        let foot = model.panelFoot
        return surfaceIsOut && motion.progress == 0 ? PanelFoot(closed: foot.open, open: foot.open) : foot
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
