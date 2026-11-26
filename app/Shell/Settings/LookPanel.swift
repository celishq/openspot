import OpenspotCore
import SwiftUI

struct LookPanel: View {
    let swatch: Theme.Appearance
    let layout: Theme.Layout
    let isClear: Bool
    let spots: [LookSpot]

    private var cell: CGFloat { CGFloat(layout.space.cell) }
    private var gap: CGFloat { CGFloat(layout.space.columnGap) }
    private var padding: CGFloat { CGFloat(layout.space.padding) }

    var size: CGSize {
        let (columns, rows) = (SpotTokens.settingsLookColumns, SpotTokens.settingsLookRows)
        return CGSize(width: columns * cell + (columns - 1) * gap + 2 * padding, height: rows * cell + (rows - 1) * CGFloat(layout.space.rowGap) + 2 * padding)
    }

    var body: some View {
        let plate = SpotRoundShape(radius: CGFloat(layout.radius.card) + padding)
        VStack(alignment: .leading, spacing: CGFloat(layout.space.rowGap)) {
            field
            HStack(spacing: gap) {
                ForEach(0..<2, id: \.self) { card(at: $0, columns: 2) }
            }
            HStack(spacing: gap) {
                ForEach(2..<6, id: \.self) { card(at: $0, columns: 1) }
            }
        }
        .padding(padding)
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(swatch.background.color.opacity(isClear ? SpotTheme.settingsLookClearFill : SpotTheme.settingsLookPanelFill), in: plate)
        .overlay(plate.strokeBorder(isClear ? SpotTheme.settingsLookClearRim : swatch.ink.color.opacity(SpotTheme.settingsLookCell), lineWidth: SpotTokens.settingsLookCardRing / 2))
    }

    private var field: some View {
        HStack(spacing: SpotTokens.fieldTextGap) {
            Image(systemName: "magnifyingglass")
            Text("Search")
        }
        .font(SpotType.input)
        .foregroundStyle(swatch.ink.color.opacity(SpotTheme.settingsLookHint))
        .padding(.horizontal, padding)
        .frame(maxWidth: .infinity, minHeight: cell, maxHeight: cell, alignment: .leading)
        .background(swatch.ink.color.opacity(SpotTheme.settingsLookCell), in: SpotRoundShape(radius: cell / 2))
    }

    private func card(at index: Int, columns: Int) -> some View {
        let spot = spots.isEmpty ? nil : spots[index % spots.count]
        let shape = SpotRoundShape(radius: columns == 1 ? cell / 2 : CGFloat(layout.radius.card))
        let isChosen = index == 0
        return HStack(spacing: SpotTokens.wordsGap) {
            Image(systemName: spot?.symbol ?? "square")
                .font(.system(size: CGFloat(layout.space.glyph), weight: .semibold))
                .foregroundStyle(isChosen ? swatch.accent.color : swatch.ink.color)
            if columns > 1, let name = spot?.name, !name.isEmpty {
                Text(name)
                    .font(SpotType.title)
                    .foregroundStyle(swatch.ink.color)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, columns > 1 ? padding : 0)
        .frame(width: CGFloat(columns) * cell + CGFloat(columns - 1) * gap, height: cell, alignment: columns > 1 ? .leading : .center)
        .background(swatch.ink.color.opacity(SpotTheme.settingsLookCell), in: shape)
        .overlay(shape.strokeBorder(isChosen ? swatch.accent.color : .clear, lineWidth: SpotTokens.settingsLookCardRing))
    }
}
