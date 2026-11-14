import OpenspotCore
import SwiftUI

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
