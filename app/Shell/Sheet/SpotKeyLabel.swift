import OpenspotCore
import SwiftUI

struct SpotKeyLabel: View {
    let text: String
    let isRecording: Bool
    var recordingWords = "Press keys"

    var body: some View {
        Text(isRecording ? recordingWords : text == KeyList.unset ? "Not set" : Trigger(text: text)?.label ?? text)
            .font(SpotType.action)
            .foregroundStyle(SpotTheme.ink)
            .padding(.horizontal, SpotTokens.padding)
            .padding(.vertical, 5)
            .fixedSize()
            .background(SpotTheme.ink.opacity(SpotTheme.selectedFill), in: Capsule())
            .contentShape(Capsule())
    }
}
