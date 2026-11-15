import OpenspotCore
import SwiftUI

struct SpotSheetTitle: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(title)
                .font(SpotType.title)
                .frame(height: SpotType.titleLine)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .frame(height: SpotType.detailLine)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
            }
        }
    }
}
