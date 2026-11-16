import OpenspotCore
import SwiftUI

struct SpotSearchField: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let prompt: String
    let text: String
    let onSearch: @MainActor @Sendable (String) -> Void
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField(prompt, text: Binding(get: { text }, set: onSearch), prompt: Text(""))
            .labelsHidden()
            .textFieldStyle(.plain)
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .focused(isFocused)
            .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
            .frame(height: SpotTokens.menuRowHeight)
            .contentShape(shape)
            .pointerStyle(.horizontalText)
            .simultaneousGesture(TapGesture().onEnded { isFocused.wrappedValue = true })
    }

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }
}
