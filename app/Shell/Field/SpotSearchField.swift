import OpenspotCore
import SwiftUI

/// The field that searches the rows or the spots of a surface: its words on the fill of a row, and its prompt in the
/// secondary strength of ink. A click anywhere on the fill puts the text cursor in it.
struct SpotSearchField: View {
    let prompt: String
    let text: String
    let onSearch: @MainActor @Sendable (String) -> Void
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField(prompt, text: Binding(get: { text }, set: onSearch), prompt: Text(prompt).foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight)))
            .labelsHidden()
            .textFieldStyle(.plain)
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .focused(isFocused)
            .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
            .frame(height: SpotTokens.menuRowHeight)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .contentShape(shape)
            .pointerStyle(.horizontalText)
            .simultaneousGesture(TapGesture().onEnded { isFocused.wrappedValue = true })
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }
}
