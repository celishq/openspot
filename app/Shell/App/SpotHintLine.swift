import OpenspotCore
import SwiftUI

struct SpotHintLine: View {
    let model: SpotsModel
    let surfaceIsOut: Bool
    let motion: SheetMotion

    var body: some View {
        ZStack(alignment: .top) {
            hint(model.waiting ?? model.gridHint, isWorking: model.waiting != nil, isShown: !surfaceIsOut)
            hint(model.waiting ?? sheetWords, isWorking: model.waiting != nil, isShown: surfaceIsOut)
        }
        .modifier(FootOffset(foot: foot, motion: motion, inset: SpotTokens.halo + SpotTokens.hintPillHeight))
        .onAppear { model.followHint() }
    }

    private var foot: PanelFoot {
        let foot = model.panelFoot
        return surfaceIsOut && motion.progress == 0 ? PanelFoot(closed: foot.open, open: foot.open) : foot
    }

    private func hint(_ words: HintWords, isWorking: Bool, isShown: Bool) -> some View {
        ZStack {
            ForEach([HintCopy(words: words, isWorking: isWorking)], id: \.self) { copy in
                SpotHint(words: copy.words, activeKey: model.isMenuOpen ? ActionMenu.key : nil, isWorking: copy.isWorking, onPress: model.pressHint)
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

private struct HintCopy: Hashable {
    let words: HintWords
    let isWorking: Bool
}
