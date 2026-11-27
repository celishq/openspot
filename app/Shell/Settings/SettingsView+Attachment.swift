import OpenspotCore
import SwiftUI

extension SettingsView {
    func attachmentGroup(_ standing: SpotStanding, _ rows: SettingRows.Group) -> some View {
        group(rows.id) {
            lines(rows.rows) { settingLine($0) }
            lines(standing.attachmentNeeds.compactMap(book.access.access)) { accessLine($0) }
        }
    }

    private func accessLine(_ access: AccessList.Entry) -> some View {
        row(open: .accessOf(access.id)) {
            SettingsTile(access: access.id, side: SpotTokens.settingsRowTile)
            Text(access.id.title)
                .lineLimit(1)
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            if access.isAllowed {
                Text(access.status.word).foregroundStyle(.secondary)
            } else {
                Text(access.status.word).foregroundStyle(SpotTheme.settings(access.status))
                Button("Allow") { act { await $0.allow(access: access.id) } }
            }
            chevron
        }
    }
}
