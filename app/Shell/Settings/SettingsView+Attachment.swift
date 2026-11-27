import OpenspotCore
import SwiftUI

extension SettingsView {
    func attachmentGroup(_ standing: SpotStanding, _ rows: SettingRows.Group) -> some View {
        Section {
            if let chip = standing.attachmentChip {
                SettingsAttachmentPicture(chip: chip)
            }
            lines(rows.rows) { settingLine($0) }
            lines(standing.attachmentAccess) { useLine($0) }
        } header: {
            Text(rows.id)
                .font(SpotType.settingsGroup)
                .foregroundStyle(.primary)
        } footer: {
            if let line = standing.attachmentLine {
                Text(line)
                    .font(SpotType.settingsLine)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
