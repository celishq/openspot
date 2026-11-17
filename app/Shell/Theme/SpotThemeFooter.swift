import AppKit
import OpenspotCore
import SwiftUI

struct SpotThemeFooter: View {
    let model: SpotThemeModel
    let hint: String
    @State private var isHovered = false
    @State private var isTipShown = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: SpotTokens.themeSpacing) {
                button("plus.square.on.square", "Duplicate") { model.duplicate() }
                button("pencil", "Rename") { model.renaming = model.inUse }
                    .disabled(model.isBuiltIn)
                button("trash", "Move to Trash") { model.delete(model.inUse) }
                    .disabled(model.isBuiltIn)
            }
            .buttonStyle(.borderless)
            .padding(.leading, SpotTokens.themeRowPadding)
            .frame(width: SpotTokens.themeListWidth, alignment: .leading)
            .padding(.trailing, SpotTokens.themeGap)
            HStack(spacing: SpotTokens.hintGroupGap) {
                Text(hint)
                    .font(SpotType.builtIn.body)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, SpotTokens.themeRowPadding)
                Spacer(minLength: 0)
                Button("Done") { NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .onHover { isHovered = $0 }
                    .overlay(alignment: .topTrailing) {
                        if isTipShown {
                            SpotTipPill(text: "Close the editor")
                                .alignmentGuide(.top) { $0[.bottom] + SpotTokens.tipGap }
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .padding(.leading, SpotTokens.themePadding)
        .padding([.trailing, .bottom], SpotTokens.themePadding)
        .padding(.top, SpotTokens.themeGap)
        .task(id: isHovered) {
            isTipShown = false
            guard isHovered else { return }
            try? await Task.sleep(for: SpotTipView.delay)
            if !Task.isCancelled { isTipShown = true }
        }
    }

    private func button(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { action() } label: { Image(systemName: symbol) }
            .help(label)
            .accessibilityLabel(label)
    }
}
