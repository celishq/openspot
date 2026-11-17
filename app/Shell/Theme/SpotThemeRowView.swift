import OpenspotCore
import SwiftUI

struct SpotThemeRowView: View {
    let row: ThemeRow
    let isLocked: Bool
    let model: SpotThemeModel

    var body: some View {
        HStack(spacing: SpotTokens.menuPadding) {
            VStack(alignment: .leading, spacing: 0) {
                Text(row.key).font(SpotType.body).lineLimit(1)
                if !row.cells.contains(where: \.isSet) {
                    Text("From \(ThemeFolder.builtInName)").font(SpotType.detail).foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                }
            }
            Spacer(minLength: 0)
            ForEach(row.cells, id: \.section) { cell in
                SpotThemeCell(key: row.key, kind: row.kind, cell: cell, isLocked: isLocked, model: model)
                    .frame(width: SpotTokens.themeCellWidth, alignment: .leading)
            }
        }
        .padding(.horizontal, SpotTokens.themeRowPadding)
        .frame(minHeight: SpotTokens.themeLine)
        .background { RowPick(id: row.id, model: model) }
    }
}

private struct RowPick: View {
    let id: String
    let model: SpotThemeModel
    @Environment(\.spotSurfaceEdge) private var edge

    var body: some View {
        if model.picked == id { SpotRoundShape(edge.inner()).fill(SpotTheme.accent.opacity(SpotTheme.markFill)) }
    }
}
