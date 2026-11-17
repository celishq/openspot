import OpenspotCore
import SwiftUI

struct SpotThemeRowView: View {
    let row: ThemeRow
    let isLocked: Bool
    let model: SpotThemeModel

    var body: some View {
        HStack(spacing: SpotTokens.menuPadding) {
            VStack(alignment: .leading, spacing: 0) {
                Text(row.key).lineLimit(1)
                if !row.cells.contains(where: \.isSet) {
                    Text("From \(ThemeFolder.builtInName)").font(SpotType.detail).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            ForEach(row.cells, id: \.section) { cell in
                SpotThemeCell(key: row.key, kind: row.kind, cell: cell, isLocked: isLocked, model: model)
                    .frame(width: SpotTokens.themeCellWidth, alignment: .leading)
            }
        }
    }
}
