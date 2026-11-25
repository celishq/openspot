import OpenspotCore
import SwiftUI

extension SettingsView {
    var lookPage: some View {
        Group {
            pageHeader(.look)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: SpotTokens.settingsLookColumn), spacing: SpotTokens.settingsLookGap)], spacing: SpotTokens.settingsLookGap) {
                ForEach(facts.looks) { look in
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

    private func preview(_ look: SettingsFacts.Look) -> some View {
        let swatch = scheme == .dark ? look.colours.dark : look.colours.light
        let shape = SpotRoundShape(radius: SpotTokens.settingsCorner)
        let columns = CGFloat(SpotTheme.settingsLookCards.count)
        let width = columns * SpotTokens.cell + (columns - 1) * SpotTokens.columnGap + 2 * SpotTokens.padding
        let height = 2 * (SpotTokens.padding + SpotTokens.cell) + SpotTokens.rowGap
        let scale = (SpotTokens.settingsLookHeight - 2 * SpotTokens.settingsLookTopInset) / height
        return ZStack {
            LinearGradient(colors: scheme == .dark ? SpotTheme.settingsLookWallDark : SpotTheme.settingsLookWallLight, startPoint: .topLeading, endPoint: .bottomTrailing)
            panelTop(swatch, width: width, height: height)
                .scaleEffect(scale)
                .frame(width: width * scale, height: height * scale)
        }
        .frame(height: SpotTokens.settingsLookHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(look.isUsed ? Color.accentColor : Color.primary.opacity(SpotTheme.settingsStepFill), lineWidth: look.isUsed ? SpotTokens.settingsLookRing : SpotTokens.settingsRim))
    }

    private func panelTop(_ swatch: Theme.Appearance, width: CGFloat, height: CGFloat) -> some View {
        let card = SpotRoundShape(radius: SpotTokens.cardRadius)
        let plate = SpotRoundShape(radius: SpotTokens.cardRadius + SpotTokens.padding)
        return VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.fieldTextGap) {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .font(SpotType.input)
            .foregroundStyle(swatch.ink.color.opacity(SpotTheme.settingsLookHint))
            .padding(.horizontal, SpotTokens.padding)
            .frame(maxWidth: .infinity, minHeight: SpotTokens.cell, maxHeight: SpotTokens.cell, alignment: .leading)
            .background(swatch.ink.color.opacity(SpotTheme.settingsLookCell), in: card)
            HStack(spacing: SpotTokens.columnGap) {
                ForEach(Array(SpotTheme.settingsLookCards.enumerated()), id: \.offset) { index, symbol in
                    let isChosen = index == 0
                    Image(systemName: symbol)
                        .font(.system(size: SpotTokens.glyph, weight: .semibold))
                        .foregroundStyle(isChosen ? swatch.accent.color : swatch.ink.color)
                        .padding(SpotTokens.glyphInset)
                        .frame(maxWidth: .infinity, minHeight: SpotTokens.cell, maxHeight: SpotTokens.cell, alignment: .topLeading)
                        .background(swatch.ink.color.opacity(SpotTheme.settingsLookCell), in: card)
                        .overlay(card.strokeBorder(isChosen ? swatch.accent.color : .clear, lineWidth: SpotTokens.settingsLookCardRing))
                }
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: width, height: height, alignment: .top)
        .background(swatch.background.color.opacity(SpotTheme.settingsLookPanelFill), in: plate)
        .overlay(plate.strokeBorder(swatch.ink.color.opacity(SpotTheme.settingsLookCell), lineWidth: SpotTokens.settingsLookCardRing / 2))
    }
}
