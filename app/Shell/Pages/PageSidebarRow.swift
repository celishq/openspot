import OpenspotCore
import SwiftUI

struct PageSidebarRow<Icon: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let icon: Icon
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: SpotTokens.settingsGroupGap) {
            icon
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
            trailing
        }
    }
}
