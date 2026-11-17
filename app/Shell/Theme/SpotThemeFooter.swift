import OpenspotCore
import SwiftUI

struct SpotThemeFooter: View {
    let model: SpotThemeModel
    let hint: String

    var body: some View {
        SpotWindowFooter(hint: hint, tip: "Close the editor") {
            HStack(spacing: SpotTokens.themeSpacing) {
                button("plus.square.on.square", "Duplicate") { model.duplicate() }
                button("pencil", "Rename") { model.renaming = model.inUse }
                    .disabled(model.isBuiltIn)
                button("trash", "Move to Trash") { model.delete(model.inUse) }
                    .disabled(model.isBuiltIn)
            }
            .buttonStyle(.borderless)
            .padding(.leading, SpotTokens.themeRowPadding)
            .frame(width: SpotTokens.themeListWidth, alignment: .leading)
            .padding(.trailing, SpotTokens.themeGap)
        }
    }

    private func button(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { action() } label: { Image(systemName: symbol) }
            .help(label)
            .accessibilityLabel(label)
    }
}
