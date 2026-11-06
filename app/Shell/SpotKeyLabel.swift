import OpenspotCore
import SwiftUI

/// A key at the end of a line, or the words that ask for one while it records.
struct SpotKeyLabel: View {
    let text: String
    let isRecording: Bool

    var body: some View {
        Text(isRecording ? "Press keys" : Shortcut(text: text)?.label ?? text)
            .font(SpotType.action)
            .foregroundStyle(.white)
            .padding(.horizontal, SpotTokens.padding)
            .padding(.vertical, 5)
            .fixedSize()
            .background(Color.white.opacity(SpotTokens.selectedFill), in: Capsule())
            .contentShape(Capsule())
    }
}
