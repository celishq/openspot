import OpenspotCore
import SwiftUI

struct SpotSteadyField: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let prompt: String
    let text: String
    let isSettled: Bool
    let onSearch: @MainActor @Sendable (String) -> Void
    @FocusState private var isFocused: Bool

    private static let textFieldRise: CGFloat = 1

    var body: some View {
        ZStack {
            words(prompt)
                .foregroundStyle(SpotTheme.glassSecondary)
                .opacity(text.isEmpty ? 1 : MotionTokens.hiddenOpacity)
            words(text)
                .foregroundStyle(SpotTheme.glassInk)
                .animation(nil) { $0.opacity(isSettled || text.isEmpty ? MotionTokens.hiddenOpacity : 1) }
            SpotSearchField(prompt: prompt, text: text, onSearch: onSearch, isFocused: $isFocused)
                .animation(nil) { $0.opacity(isSettled ? 1 : MotionTokens.hiddenOpacity) }
        }
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: SpotRoundShape(surface.inner()))
        .onAppear {
            DispatchQueue.main.async { isFocused = true }
        }
    }

    private func words(_ words: String) -> some View {
        Text(words)
            .font(SpotType.body)
            .lineLimit(1)
            .offset(y: -Self.textFieldRise)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpotTokens.menuTextInset)
            .frame(height: SpotTokens.menuRowHeight)
            .allowsHitTesting(false)
    }
}
