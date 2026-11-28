import AppKit
import OpenspotCore
import SwiftUI

extension SettingsView {
    var lookPage: some View {
        let spots = model.visible.filter { NSImage(systemSymbolName: $0.spot.symbol, accessibilityDescription: nil) != nil }
            .prefix(SpotTokens.settingsLookSpots).map { LookSpot(symbol: $0.spot.symbol, name: $0.spot.name) }
        let shown = spots.isEmpty ? SpotTheme.settingsLookCards.map { LookSpot(symbol: $0, name: "") } : Array(spots)
        return Group {
            title(of: .look)
            tiles {
                ForEach(book.looks) { tile($0, spots: shown) }
                makeTile
            }
        }
    }

    private func tile(_ look: ListedTheme, spots: [LookSpot]) -> some View {
        VStack(spacing: SpotTokens.settingsLookWords) {
            preview(look, spots: spots)
            HStack(spacing: SpotTokens.settingsLookWords) {
                if !look.isBuiltIn {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(.secondary)
                        .help("Yours")
                }
                Text(look.id)
                    .fontWeight(look.isUsed ? .semibold : .regular)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !look.isUsed { act { await $0.use(theme: look.id) } } }
        .contextMenu {
            Button("Use") { act { await $0.use(theme: look.id) } }
                .disabled(look.isUsed)
            Button("Duplicate") { act { await $0.duplicate(theme: look.id) } }
            if !look.isBuiltIn {
                Divider()
                Button("Move to Trash") { act { await $0.delete(theme: look.id) } }
            }
        }
        .accessibilityAddTraits(look.isUsed ? [.isButton, .isSelected] : .isButton)
        .help(look.isUsed ? "\(look.id) is in use" : "Use \(look.id)")
    }

    private var makeTile: some View {
        let shape = SpotRoundShape(radius: SpotTokens.pageTileRadius)
        return VStack(spacing: SpotTokens.settingsLookWords) {
            Image(systemName: "plus")
                .font(SpotType.settingsTitle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: SpotTokens.settingsLookHeight)
                .overlay(shape.strokeBorder(Color.primary.opacity(SpotTheme.settingsStepFill), style: StrokeStyle(lineWidth: SpotTokens.settingsRim, dash: SpotTokens.settingsLookDash)))
            Text("Make a Theme")
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { isThemeAsked = true }
        .accessibilityAddTraits(.isButton)
        .help("Describe a theme, and copy a prompt for your coding agent")
    }

    var themeForm: some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsSheetGap) {
            VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                Text("Make a theme")
                    .font(SpotType.settingsTitle)
                Text("Describe the look you want. Copy the prompt, and give it to your coding agent.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("Warm colours, round corners, clear glass", text: $themeWish, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(SpotTokens.settingsWishLines, reservesSpace: true)
                .onChange(of: themeWish) { isThemeCopied = false }
            HStack(spacing: SpotTokens.settingsRowGap) {
                Spacer()
                Button("Cancel") { isThemeAsked = false }
                    .keyboardShortcut(.cancelAction)
                Button(isThemeCopied ? "✓ Copied" : "Copy Prompt") { copyThemePrompt() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .controlSize(.large)
            .padding(.top, SpotTokens.settingsSheetTop)
        }
        .padding(SpotTokens.settingsSheetPadding)
        .frame(width: SpotTokens.settingsSheetWidth, alignment: .leading)
    }

    private func copyThemePrompt() {
        let words = themeWish
        act { book in
            guard let prompt = await book.themePrompt(words: words) else { return }
            try? SpotClipboard().copy(text: prompt)
            isThemeCopied = true
        }
    }

    private func preview(_ look: ListedTheme, spots: [LookSpot]) -> some View {
        let shape = SpotRoundShape(radius: SpotTokens.pageTileRadius)
        let isDark = colorScheme == .dark
        let swatch = isDark ? look.colours.dark : look.colours.light
        return ZStack {
            swatch.background.color
            LinearGradient(colors: [swatch.accent.color.opacity(SpotTheme.settingsLookWall), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            LookPictures.shared.picture(of: look, isDark: isDark, spots: spots)?
                .resizable()
                .scaledToFit()
                .frame(height: SpotTokens.settingsLookHeight * SpotTokens.settingsLookFill)
        }
        .frame(height: SpotTokens.settingsLookHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(look.isUsed ? Color.accentColor : Color.primary.opacity(SpotTheme.settingsStepFill), lineWidth: look.isUsed ? SpotTokens.settingsLookRing : SpotTokens.settingsRim))
        .task(id: LookPictures.Key(colours: look.colours, layout: look.layout, isDark: isDark, spots: spots)) { LookPictures.shared.draw(look, isDark: isDark, spots: spots) }
    }
}
