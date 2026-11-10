import OpenspotCore
import SwiftUI

/// A round tick before the words of a thing to do: a ring while it is open, and a filled tick when it is done. It takes the
/// place of a row's picture, so its words line up with the words of other rows. A press sends the other state, and the
/// words fade when it is done.
struct SpotTick<Words: View>: View {
    let isOn: Bool
    let words: Words
    let onPress: (Bool) -> Void

    var body: some View {
        HStack(spacing: SpotTokens.padding - 5) {
            Button { onPress(!isOn) } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(SpotType.body.weight(.regular))
                    .imageScale(.large)
                    .foregroundStyle(SpotTheme.ink.opacity(isOn ? SpotTheme.secondaryLight : 1))
                    .frame(width: SpotTokens.listIconSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isOn ? "Open again" : "Done")
            words.opacity(isOn ? SpotTheme.secondaryLight : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
