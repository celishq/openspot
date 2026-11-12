import OpenspotCore
import SwiftUI

/// The name of a group of the store and the number of its spots.
struct SpotGroupTitle: View {
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(SpotType.title)
                .foregroundStyle(SpotTheme.ink)
            Text("\(count)")
                .font(SpotType.body)
                .modifier(SpotSecondaryText())
        }
        .frame(height: SpotTokens.groupTitleHeight)
    }
}
