import OpenspotCore
import SwiftUI

extension SettingsView {
    func placesGroup(_ standing: SpotStanding, _ rows: SettingRows.Group) -> some View {
        Section {
            HStack(alignment: .top, spacing: SpotTokens.pageTileGap) {
                ForEach(rows.rows) { placeTile($0, of: standing) }
                Spacer(minLength: 0)
            }
            .padding(.vertical, SpotTokens.settingsRowGap)
        } header: {
            Text(rows.id)
                .font(SpotType.settingsGroup)
                .foregroundStyle(.primary)
        } footer: {
            if let line = rows.rows.compactMap(\.detail).first {
                Text(line)
                    .font(SpotType.settingsLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func accessLine(_ access: AccessList.Entry) -> some View {
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

    private func placeTile(_ row: SettingRow, of standing: SpotStanding) -> some View {
        let isOn = book.value(of: row).isOn
        let shape = SpotRoundShape(radius: SpotTokens.settingsPlaceRadius)
        return VStack(spacing: SpotTokens.settingsLookWords) {
            SettingsPlacePicture(place: row.key, spot: standing.spot, chip: standing.attachmentChip, isOn: isOn)
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.accentColor, lineWidth: SpotTokens.settingsLookRing).opacity(isOn ? 1 : MotionTokens.hiddenOpacity))
            Text(SpotRows.placeName(of: row.key) ?? row.title)
                .lineLimit(1)
        }
        .frame(width: SpotTokens.settingsPlaceWidth)
        .contentShape(Rectangle())
        .onTapGesture { act { await $0.set(row, on: !isOn) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .help(row.title)
    }
}
