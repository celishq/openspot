import OpenspotCore
import SwiftUI

/// What takes the place of the grid while a `.spot` file is dragged over the panel: what the file is, and that a drop installs it.
struct SpotDropView: View {
    let drop: SpotDrop

    var body: some View {
        VStack(spacing: SpotTokens.rowGap) {
            Image(systemName: drop.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 2 * SpotTokens.glyphSize, height: 2 * SpotTokens.glyphSize)
                .background(Color.white.opacity(0.2), in: Circle())
            Text(drop.title)
                .font(SpotType.title)
                .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                .multilineTextAlignment(.center)
            if let detail = drop.detail {
                Text(detail)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .multilineTextAlignment(.center)
            }
        }
        .padding(SpotTokens.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(SpotGlass())
    }
}
