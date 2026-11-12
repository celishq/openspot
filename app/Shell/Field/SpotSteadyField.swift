import OpenspotCore
import SwiftUI

/// A search field that takes the focus as it shows, and whose words keep still while the layer around it moves. A text
/// field of AppKit lies at its layout place, so it does not follow a scale, and draws its words lower without the focus.
/// Until the layer settles, a SwiftUI copy that sits on the focused field's pixels stands in for it, and the two swap at
/// once, never by a fade.
struct SpotSteadyField: View {
    let prompt: String
    let text: String
    /// Whether the layer around the field has stopped moving.
    let isSettled: Bool
    let onSearch: @MainActor @Sendable (String) -> Void
    @FocusState private var isFocused: Bool

    /// How far a text field of AppKit draws its words above a SwiftUI text in the same frame.
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
