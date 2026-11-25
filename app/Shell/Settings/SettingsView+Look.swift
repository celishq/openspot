import OpenspotCore
import SwiftUI

extension SettingsView {
    var lookPage: some View {
        Group {
            heading(SettingsPage.look.section.title, SettingsPage.look.line)
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
        let cell = SpotRoundShape(radius: SpotTokens.settingsLookCellCorner)
        return ZStack {
            LinearGradient(colors: SpotTheme.settingsLookWall, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: SpotTokens.settingsLookCellGap) {
                Capsule().fill(swatch.ink.color.opacity(SpotTheme.settingsLookInk)).frame(height: SpotTokens.settingsLookBar)
                ForEach(0..<3) { line in
                    HStack(spacing: SpotTokens.settingsLookCellGap) {
                        ForEach(0..<3) { column in
                            cell.fill(line == 0 && column == 0 ? swatch.accent.color : swatch.ink.color.opacity(SpotTheme.settingsLookCell))
                        }
                    }
                }
            }
            .padding(SpotTokens.settingsLookPanelPadding)
            .background(swatch.background.color.opacity(SpotTheme.settingsLookPanel), in: SpotRoundShape(radius: SpotTokens.settingsLookPanelCorner))
            .padding(.horizontal, SpotTokens.settingsLookSideInset)
            .padding(.vertical, SpotTokens.settingsLookTopInset)
        }
        .frame(height: SpotTokens.settingsLookHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(look.isUsed ? Color.accentColor : Color.primary.opacity(SpotTheme.settingsStepFill), lineWidth: look.isUsed ? SpotTokens.settingsLookRing : SpotTokens.settingsRim))
    }
}
