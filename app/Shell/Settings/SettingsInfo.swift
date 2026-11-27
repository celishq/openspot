import OpenspotCore
import SwiftUI

struct SettingsInfo: View {
    let text: String
    @State private var isShown = false

    var body: some View {
        Button { isShown.toggle() } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More about this")
        .popover(isPresented: $isShown, arrowEdge: .bottom) {
            Text(text)
                .font(SpotType.settingsLine)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: SpotTokens.settingsInfoWidth, alignment: .leading)
                .padding(SpotTokens.settingsInfoPadding)
        }
    }
}
