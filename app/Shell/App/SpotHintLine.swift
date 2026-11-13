import OpenspotCore
import SwiftUI

/// The hint under the grid and the hint under the sheet. Each stays at its own place and keeps the words it last showed, so
/// that one fades out with its words before the other fades in. New words at one place cross-fade with the old ones, each
/// laid out once. It alone reads the model's hints, so a change of the words reruns this view and not the panel.
struct SpotHintLine: View {
    let model: SpotsModel
    /// Whether a sheet is out or a drop is taken, which sets the time of each fade and which hint shows.
    let surfaceIsOut: Bool
    let gridHeight: CGFloat
    let sheetHeight: CGFloat
    @Environment(\.spotPanelWidth) private var panelWidth

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
        .frame(width: panelWidth)
        .allowsHitTesting(isShown)
        .offset(y: height - SpotTokens.halo - SpotTokens.hintPillHeight)
        .morph(isShown ? 1 : 0, opacity: { SheetMorph.sheetLook(at: $0) })
    }

    /// What the hint says while a sheet shows: a form has its own keys.
    private var sheetWords: HintWords {
        guard model.formRect != nil else { return model.sheetHint }
        if model.formIsMultiple { return Self.multipleForm }
        return model.formHasChoices ? Self.choiceForm : Self.form
    }

    private static let multipleForm = HintWords("⏎ Select   ⌘⇧A Select all   Esc Done")
    private static let choiceForm = HintWords("⏎ Save   Esc Cancel")
    private static let form = HintWords("⌘⏎ Save   Esc Cancel")
}
