import AppKit
import OpenspotCore
import SwiftUI

struct SpotWindowFooter<Lead: View>: View {
    let hint: String
    let tip: String
    @ViewBuilder let lead: Lead
    @State private var isHovered = false
    @State private var isTipShown = false

    var body: some View {
        HStack(spacing: 0) {
            lead
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
                            SpotTipPill(text: tip)
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
}
