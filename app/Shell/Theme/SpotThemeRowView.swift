import OpenspotCore
import SwiftUI

struct SpotThemeRowView: View {
    let row: ThemeRow
    let isLocked: Bool
    let model: SpotThemeModel

    var body: some View {
        HStack(spacing: SpotTokens.themeSpacing) {
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name).font(SpotType.builtIn.body).lineLimit(1)
                if !row.cells.contains(where: \.isSet) {
                    Text("From \(ThemeFolder.builtInName)").font(SpotType.builtIn.detail).foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                }
            }
            Spacer(minLength: 0)
            ForEach(row.cells, id: \.key) { cell in
                SpotThemeCell(kind: row.kind, cell: cell, isLocked: isLocked, model: model)
                    .frame(width: SpotTokens.themeCellWidth, alignment: .leading)
            }
        }
        .modifier(SpotThemeBand())
        .background { RowPick(id: row.id, model: model) }
    }
}

private struct RowPick: View {
    let id: ThemeKey
    let model: SpotThemeModel
    var body: some View {
        SpotThemeBand.fill(isChosen: model.picked == id)
    }
}
