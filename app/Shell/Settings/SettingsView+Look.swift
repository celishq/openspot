import OpenspotCore
import SwiftUI

extension SettingsView {
    var lookPage: some View {
        Group {
            pageHeader(.look)
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: SpotTokens.settingsLookColumn), spacing: SpotTokens.settingsLookGap)], spacing: SpotTokens.settingsLookGap) {
                    ForEach(book.looks) { look in
                        VStack(spacing: SpotTokens.settingsLookWords) {
                            preview(look)
                            Text(look.id)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(look.word)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { if !look.isUsed { act { await $0.use(theme: look.id) } } }
                        .help(look.isUsed ? "\(look.id) is in use" : "Use \(look.id)")
                    }
                }
            }
        }
    }

    private func preview(_ look: ListedTheme) -> some View {
        let shape = SpotRoundShape(radius: SpotTokens.settingsCorner)
        return ZStack {
            half(look, look.colours.dark, wall: SpotTheme.settingsLookWallDark)
            half(look, look.colours.light, wall: SpotTheme.settingsLookWallLight)
                .mask {
                    GeometryReader { box in
                        Rectangle()
                            .frame(width: box.size.width / 2)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
        }
        .frame(height: SpotTokens.settingsLookHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(look.isUsed ? Color.accentColor : Color.primary.opacity(SpotTheme.settingsStepFill), lineWidth: look.isUsed ? SpotTokens.settingsLookRing : SpotTokens.settingsRim))
        .overlay(alignment: .topTrailing) {
            if look.isUsed {
                Image(systemName: "checkmark.circle.fill")
                    .font(SpotType.settingsLookCheck)
                    .foregroundStyle(SpotTheme.settingsSelectedInk, Color.accentColor)
                    .padding(SpotTokens.settingsLookCheckInset)
            }
        }
    }

    private func half(_ look: ListedTheme, _ swatch: Theme.Appearance, wall: [Color]) -> some View {
        let layout = look.layout
        let columns = CGFloat(SpotTheme.settingsLookCards.count)
        let width = columns * CGFloat(layout.space.cell) + (columns - 1) * CGFloat(layout.space.columnGap) + 2 * CGFloat(layout.space.padding)
        let height = 2 * (CGFloat(layout.space.padding) + CGFloat(layout.space.cell)) + CGFloat(layout.space.rowGap)
        let scale = (SpotTokens.settingsLookHeight - 2 * SpotTokens.settingsLookTopInset) / height
        return ZStack {
            LinearGradient(colors: wall, startPoint: .topLeading, endPoint: .bottomTrailing)
            panelTop(swatch, layout, width: width, height: height)
                .scaleEffect(scale)
                .frame(width: width * scale, height: height * scale)
        }
    }

    private func panelTop(_ swatch: Theme.Appearance, _ layout: Theme.Layout, width: CGFloat, height: CGFloat) -> some View {
        let card = SpotRoundShape(radius: CGFloat(layout.radius.card))
        let plate = SpotRoundShape(radius: CGFloat(layout.radius.card) + CGFloat(layout.space.padding))
        return VStack(alignment: .leading, spacing: CGFloat(layout.space.rowGap)) {
            HStack(spacing: SpotTokens.fieldTextGap) {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .font(SpotType.input)
            .foregroundStyle(swatch.ink.color.opacity(SpotTheme.settingsLookHint))
            .padding(.horizontal, CGFloat(layout.space.padding))
            .frame(maxWidth: .infinity, minHeight: CGFloat(layout.space.cell), maxHeight: CGFloat(layout.space.cell), alignment: .leading)
            .background(swatch.ink.color.opacity(SpotTheme.settingsLookCell), in: card)
            HStack(spacing: CGFloat(layout.space.columnGap)) {
                ForEach(Array(SpotTheme.settingsLookCards.enumerated()), id: \.offset) { index, symbol in
                    let isChosen = index == 0
                    Image(systemName: symbol)
                        .font(.system(size: CGFloat(layout.space.glyph), weight: .semibold))
                        .foregroundStyle(isChosen ? swatch.accent.color : swatch.ink.color)
                        .padding(SpotTokens.glyphInset)
                        .frame(maxWidth: .infinity, minHeight: CGFloat(layout.space.cell), maxHeight: CGFloat(layout.space.cell), alignment: .topLeading)
                        .background(swatch.ink.color.opacity(SpotTheme.settingsLookCell), in: card)
                        .overlay(card.strokeBorder(isChosen ? swatch.accent.color : .clear, lineWidth: SpotTokens.settingsLookCardRing))
                }
            }
        }
        .padding(CGFloat(layout.space.padding))
        .frame(width: width, height: height, alignment: .top)
        .background(swatch.background.color.opacity(SpotTheme.settingsLookPanelFill), in: plate)
        .overlay(plate.strokeBorder(swatch.ink.color.opacity(SpotTheme.settingsLookCell), lineWidth: SpotTokens.settingsLookCardRing / 2))
    }
}
