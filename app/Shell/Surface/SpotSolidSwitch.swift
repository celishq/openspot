import OpenspotCore
import SwiftUI

struct SpotSolidSwitch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let ink = SpotTheme.ink(onSolid: true)
        let isOn = configuration.isOn
        Button { configuration.isOn.toggle() } label: {
            Capsule()
                .fill(isOn ? ink : ink.opacity(SpotTheme.track))
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? SpotTheme.solid : ink.opacity(SpotTheme.secondary))
                        .padding(SpotTokens.solidSwitchInset)
                }
                .frame(width: SpotTokens.solidSwitchWidth, height: SpotTokens.solidSwitchHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
