import OpenspotCore
import SwiftUI

struct SpotHintLine: View {
    let model: SpotsModel
    let surfaceIsOut: Bool
    let gridHeight: CGFloat
    let sheetHeight: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            hint(model.gridHint, isShown: !surfaceIsOut, height: gridHeight)
            hint(sheetWords, isShown: surfaceIsOut, height: sheetHeight)
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
        guard model.formRect != nil else { return model.sheetHint }
        if model.formIsMultiple { return Self.multipleForm }
        return model.formHasChoices ? Self.choiceForm : Self.form
    }

    private static let multipleForm = HintWords("⏎ Select   ⌘⇧A Select all   Esc Done")
    private static let choiceForm = HintWords("⏎ Save   Esc Cancel")
    private static let form = HintWords("⌘⏎ Save   Esc Cancel")
}
