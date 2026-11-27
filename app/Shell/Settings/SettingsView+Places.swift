import OpenspotCore
import SwiftUI

extension SettingsView {
    func placesGroup(_ standing: SpotStanding, _ rows: SettingRows.Group) -> some View {
        group(rows.id) {
            HStack(alignment: .top, spacing: SpotTokens.pageTileGap) {
                ForEach(rows.rows) { row in
                    if let place = SpotPlace(rawValue: row.key) { placeTile(row, place, of: standing) }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, SpotTokens.settingsRowGap)
        }
    }

    private func placeTile(_ row: SettingRow, _ place: SpotPlace, of standing: SpotStanding) -> some View {
        let isOn = book.value(of: row).isOn
        return VStack(spacing: SpotTokens.settingsLookWords) {
            SettingsPlacePicture(place: place, spot: standing.spot, isOn: isOn)
                .clipShape(SpotRoundShape(radius: SpotTokens.settingsPlaceRadius))
                .contentShape(Rectangle())
                .onTapGesture { act { await $0.set(row, on: !isOn) } }
                .accessibilityHidden(true)
            HStack(spacing: SpotTokens.settingsLookWords) {
                Text(place.name)
                    .lineLimit(1)
                if let info = place.info {
                    SettingsInfo(text: info)
                }
            }
            Toggle(row.title, isOn: Binding(get: { isOn }, set: { on in act { await $0.set(row, on: on) } }))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(width: SpotTokens.settingsPlaceWidth)
        .help(row.title)
    }
}
