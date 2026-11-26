import AppKit
import OpenspotCore
import SwiftUI

extension SettingsView {
    var lookPage: some View {
        Group {
            title(of: .look)
            ForEach(["Built In", "Yours"], id: \.self) { name in
                let looks = book.looks.filter { $0.group == name }
                if !looks.isEmpty || name == "Yours" {
                    group(name) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: SpotTokens.settingsLookColumn), spacing: SpotTokens.settingsLookGap)], spacing: SpotTokens.settingsLookGap) {
                            ForEach(looks) { tile($0) }
                            if name == "Yours" { makeTile }
                        }
                    }
                }
            }
        }
    }

    private func tile(_ look: ListedTheme) -> some View {
        VStack(spacing: SpotTokens.settingsLookWords) {
            preview(look)
            Text(look.id)
                .fontWeight(look.isUsed ? .semibold : .regular)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !look.isUsed { act { await $0.use(theme: look.id) } } }
        .accessibilityAddTraits(look.isUsed ? [.isButton, .isSelected] : .isButton)
        .help(look.isUsed ? "\(look.id) is in use" : "Use \(look.id)")
    }

    private var makeTile: some View {
        let shape = SpotRoundShape(radius: SpotTokens.settingsCorner)
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
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
            isThemeCopied = true
        }
    }

    private func preview(_ look: ListedTheme) -> some View {
        let shape = SpotRoundShape(radius: SpotTokens.settingsCorner)
        let swatch = colorScheme == .dark ? look.colours.dark : look.colours.light
        let layout = look.layout
        let columns = CGFloat(SpotTheme.settingsLookCards.count)
        let width = columns * CGFloat(layout.space.cell) + (columns - 1) * CGFloat(layout.space.columnGap) + 2 * CGFloat(layout.space.padding)
        let height = 2 * (CGFloat(layout.space.padding) + CGFloat(layout.space.cell)) + CGFloat(layout.space.rowGap)
        let scale = (SpotTokens.settingsLookHeight - 2 * SpotTokens.settingsLookTopInset) / height
        return ZStack {
            swatch.background.color
            LinearGradient(colors: [swatch.accent.color.opacity(SpotTheme.settingsLookWall), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            panelTop(swatch, layout, isClear: look.colours.glass == .clear, width: width, height: height)
                .scaleEffect(scale)
                .frame(width: width * scale, height: height * scale)
        }
        .frame(height: SpotTokens.settingsLookHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(look.isUsed ? Color.accentColor : Color.primary.opacity(SpotTheme.settingsStepFill), lineWidth: look.isUsed ? SpotTokens.settingsLookRing : SpotTokens.settingsRim))
    }

    private func panelTop(_ swatch: Theme.Appearance, _ layout: Theme.Layout, isClear: Bool, width: CGFloat, height: CGFloat) -> some View {
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
        .background(swatch.background.color.opacity(isClear ? SpotTheme.settingsLookClearFill : SpotTheme.settingsLookPanelFill), in: plate)
        .overlay(plate.strokeBorder(isClear ? SpotTheme.settingsLookClearRim : swatch.ink.color.opacity(SpotTheme.settingsLookCell), lineWidth: SpotTokens.settingsLookCardRing / 2))
    }
}
