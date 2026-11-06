import OpenspotCore
import SwiftUI

/// What the search field says while a `.spot` file is dragged over the panel, and as a review grows out of it. It lies as the
/// header of a sheet lies, so that the two are one thing.
struct SpotDropView: View {
    let drop: SpotDrop

    var body: some View {
        HStack(spacing: SpotTokens.padding - 5) {
            Image(systemName: drop.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                .background(Color.white.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(drop.title)
                    .font(SpotType.title)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
                if let detail = drop.detail {
                    Text(detail)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
