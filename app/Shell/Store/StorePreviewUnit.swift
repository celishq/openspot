import OpenspotCore
import SwiftUI

struct StorePreviewUnit<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: SpotTokens.storeTileLineGap) {
            content
            Text(label)
                .font(SpotType.detail)
                .foregroundStyle(.secondary)
        }
    }
}
