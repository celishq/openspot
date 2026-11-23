import OpenspotCore
import SwiftUI

struct SpotKeyLabel: View {
    let text: String
    let isRecording: Bool
    var recordingWords = "Press keys"
    var held: Shortcut.Modifiers = []

    private var words: String {
        if isRecording { return held.isEmpty ? recordingWords : "\(held.marks) …" }
        return text == Trigger.unset ? "Not set" : Trigger(text: text)?.label ?? text
    }

    var body: some View {
        Text(words)
            .font(SpotType.action)
            .foregroundStyle(SpotTheme.ink)
            .padding(.horizontal, SpotTokens.padding)
            .padding(.vertical, SpotTokens.chipPaddingY)
            .fixedSize()
            .background(SpotTheme.highlight.opacity(SpotTheme.selectedFill), in: Capsule())
            .contentShape(Capsule())
    }
}
