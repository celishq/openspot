import OpenspotCore
import SwiftUI

/// The hint under the grid and the hint under the sheet. Each stays at its own place and keeps the words it last showed, so
/// that one fades out with its words before the other fades in. It alone reads the model's hint, so a change of the words
/// reruns this view and not the panel.
struct SpotHintLine: View {
    let model: SpotsModel
    /// Whether a sheet is out or a drop is taken, which sets the time of each fade and which hint shows.
    let surfaceIsOut: Bool
    let gridHeight: CGFloat
    let sheetHeight: CGFloat
    @State private var gridHint = ""
    @State private var sheetHint = ""
    @State private var hintIsForEdit = false

    var body: some View {
        ZStack(alignment: .top) {
            hint(gridHint, isShown: !surfaceIsOut, height: gridHeight)
            hint(sheetWords, isShown: surfaceIsOut, height: sheetHeight)
        }
        .background {
            SpotHintWatch(model: model) { hint in
                let motion = model.isEditing || hintIsForEdit || model.fieldDrop != nil ? SpotMotion.hintFade : nil
                hintIsForEdit = model.isEditing
                withAnimation(motion) {
                    if model.openList == nil, model.spotDrop == nil { gridHint = hint } else { sheetHint = hint }
                }
            }
        }
        .onChange(of: model.openList) { _, list in
            if list != nil { sheetHint = model.hint }
        }
    }

    private func hint(_ words: String, isShown: Bool, height: CGFloat) -> some View {
        SpotHint(text: words, activeKey: model.menu == nil ? nil : ActionMenu.key, onPress: model.pressHint)
            .frame(width: SpotTokens.panelWidth)
            .allowsHitTesting(isShown)
            .offset(y: height - SpotTokens.halo - SpotTokens.hintPillHeight)
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: isShown)) { $0.opacity(isShown ? 1 : 0) }
    }

    /// What the hint says while a sheet shows: a form has its own keys.
    private var sheetWords: String {
        if let form = model.form {
            if form.draft.isMultiple { return "⏎ Select   ⌘⇧A Select all   Esc Done" }
            return form.draft.choices == nil ? "⌘⏎ Save   Esc Cancel" : "⏎ Save   Esc Cancel"
        }
        return sheetHint
    }
}
