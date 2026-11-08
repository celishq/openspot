import OpenspotCore
import SwiftUI

/// A key at the end of a line, or the words that ask for one while it records.
struct SpotKeyLabel: View {
    let text: String
    let isRecording: Bool

    var body: some View {
        Text(isRecording ? "Press keys" : Shortcut(text: text)?.label ?? text)
            .font(SpotType.action)
            .foregroundStyle(SpotTheme.ink)
            .padding(.horizontal, SpotTokens.padding)
            .padding(.vertical, 5)
            .fixedSize()
            .background(SpotTheme.ink.opacity(SpotTheme.selectedFill), in: Capsule())
            .contentShape(Capsule())
    }
}
