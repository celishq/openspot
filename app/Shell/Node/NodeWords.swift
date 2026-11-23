import OpenspotCore
import SwiftUI

struct NodeWords: View {
    let part: SpotPart
    @Environment(\.spotIsOnSolid) private var isOnSolid

    var body: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            if let title = part.title {
                Text(title).font(SpotType.body).foregroundStyle(SpotTheme.ink(onSolid: isOnSolid)).lineLimit(1)
            }
            if let detail = part.detail {
                Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
            }
        }
        .modifier(SpotColorBar(color: part.color))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
