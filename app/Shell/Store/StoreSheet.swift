import OpenspotCore
import SwiftUI

struct StoreSheet<Content: View, Buttons: View>: View {
    let title: String
    let line: String
    @ViewBuilder let content: Content
    @ViewBuilder let buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsSheetGap) {
            VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                Text(title)
                    .font(SpotType.strong)
                Text(line)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
            HStack(spacing: SpotTokens.settingsRowGap) { buttons }
                .controlSize(.large)
                .padding(.top, SpotTokens.settingsSheetTop)
        }
        .font(SpotType.body)
        .fixedSize(horizontal: false, vertical: true)
        .padding(SpotTokens.settingsSheetPadding)
        .frame(width: SpotTokens.settingsSheetWidth, alignment: .leading)
    }
}
