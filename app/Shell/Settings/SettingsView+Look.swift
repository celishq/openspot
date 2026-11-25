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
        let width = SpotTokens.gridWidth
        let height = SpotTokens.cell * (SpotTokens.settingsLookRows + 1)
        let scale = SpotTokens.settingsLookPanel / width
        return ZStack(alignment: .top) {
            LinearGradient(colors: SpotTheme.settingsLookWall, startPoint: .topLeading, endPoint: .bottomTrailing)
            swatch.background.color.opacity(SpotTheme.settingsLookBackdrop)
            panelTop(swatch, width: width, height: height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: width * scale, height: height * scale, alignment: .topLeading)
                .padding(.top, SpotTokens.settingsLookTopInset)
        }
        .frame(height: SpotTokens.settingsLookHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(look.isUsed ? Color.accentColor : Color.primary.opacity(SpotTheme.settingsStepFill), lineWidth: look.isUsed ? SpotTokens.settingsLookRing : SpotTokens.settingsRim))
    }

    private func panelTop(_ swatch: Theme.Appearance, width: CGFloat, height: CGFloat) -> some View {
        let card = SpotRoundShape(radius: SpotTokens.cardRadius)
        return VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.fieldTextGap) {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .font(SpotType.input)
            .foregroundStyle(swatch.ink.color.opacity(SpotTheme.settingsLookHint))
            .padding(.horizontal, SpotTokens.padding)
            .frame(maxWidth: .infinity, minHeight: SpotTokens.cell, maxHeight: SpotTokens.cell, alignment: .leading)
            .background(swatch.background.color.opacity(SpotTheme.settingsLookPanelFill), in: card)
            ForEach(0..<Int(SpotTokens.settingsLookRows.rounded(.up)), id: \.self) { line in
                HStack(spacing: SpotTokens.columnGap) {
                    ForEach(Array(SpotTheme.settingsLookCards.enumerated()), id: \.offset) { index, symbol in
                        let isChosen = line == 0 && index == 0
                        Image(systemName: line == 0 ? symbol : SpotTheme.settingsLookCards.reversed()[index])
                            .font(.system(size: SpotTokens.glyph, weight: .semibold))
                            .foregroundStyle(isChosen ? SpotTheme.settingsTileInk : swatch.ink.color)
                            .padding(SpotTokens.glyphInset)
                            .frame(width: SpotTokens.cell, height: SpotTokens.cell, alignment: .topLeading)
                            .background(isChosen ? swatch.accent.color : swatch.background.color.opacity(SpotTheme.settingsLookPanelFill), in: card)
                            .shadow(color: isChosen ? swatch.accent.color.opacity(SpotTheme.settingsLookGlow) : .clear, radius: SpotTokens.settingsLookGlow)
                    }
                }
            }
        }
        .padding(.horizontal, SpotTokens.padding)
        .frame(width: width, height: height, alignment: .top)
    }
}
