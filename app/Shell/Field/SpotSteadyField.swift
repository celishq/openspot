import OpenspotCore
import SwiftUI

struct SpotSteadyField: View {
    let prompt: String
    let text: String
    let isSettled: Bool
    let onSearch: @MainActor @Sendable (String) -> Void
    @FocusState private var isFocused: Bool

    private static let textFieldRise: CGFloat = 1

    var body: some View {
        ZStack {
            SpotSearchField(prompt: prompt, text: text, onSearch: onSearch, isFocused: $isFocused)
                .animation(nil) { $0.opacity(isSettled ? 1 : 0.001) }
            copy
                .animation(nil) { $0.opacity(isSettled ? 0 : 1) }
        }
        .onAppear {
            DispatchQueue.main.async { isFocused = true }
        }
    }

    private var copy: some View {
        Text(text.isEmpty ? prompt : text)
            .font(SpotType.body)
            .foregroundStyle(text.isEmpty ? SpotTheme.ink.opacity(SpotTheme.secondaryLight) : SpotTheme.ink)
            .lineLimit(1)
            .offset(y: -Self.textFieldRise)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
            .frame(height: SpotTokens.menuRowHeight)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous))
            .allowsHitTesting(false)
    }
}
