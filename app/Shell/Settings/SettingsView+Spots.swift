import OpenspotCore
import SwiftUI

extension SettingsView {
    func spotPage(of standing: SpotStanding) -> some View {
        Group {
            title(.header, SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsCompactTile), standing.title, standing.detail) {}
            if let banner = standing.banner {
                self.banner(standing, banner.title, banner.line)
            }
            ForEach(book.rows.groups(of: standing.id)) { rows in
                if rows.id == SettingRows.placesGroup {
                    placesGroup(standing, rows)
                } else {
                    group(rows.id) { lines(rows.rows) { settingLine($0) } }
                }
            }
            if !standing.accesses.isEmpty {
                group("Access") {
                    lines(standing.accesses.compactMap(book.access.access)) { accessLine($0) }
                }
            }
        }
    }

    private func banner(_ standing: SpotStanding, _ title: String, _ line: String) -> some View {
        Section {
            HStack(spacing: SpotTokens.settingsRowGap) {
                Circle()
                    .fill(SpotTheme.settingsState(standing.readiness))
                    .frame(width: SpotTokens.settingsDot, height: SpotTokens.settingsDot)
                    .frame(width: SpotTokens.settingsRowTile)
                titled(title, line)
                Spacer(minLength: SpotTokens.settingsTrailingGap)
                fix(standing)
            }
        }
    }

    func spotLine(_ standing: SpotStanding, line: String = "") -> some View {
        row(open: .spotOf(standing.id)) {
            SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsRowTile)
            titled(standing.title, line)
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            if standing.lacks {
                Circle().fill(SpotTheme.settingsLate).frame(width: SpotTokens.settingsDot, height: SpotTokens.settingsDot)
                Text(standing.readiness.word)
            }
            chevron
        }
    }

    func keyLine(_ row: SettingRow, title: String? = nil) -> some View {
        HStack(spacing: SpotTokens.settingsValueGap) {
            titled(title ?? row.title, book.rows.clash(of: row.item) ?? "")
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            keycaps(row)
        }
        .listRowBackground(book.target == row.item ? Color.accentColor.opacity(SpotTheme.settingsTarget) : nil)
        .id(row.item)
    }

    func keycaps(_ row: SettingRow) -> some View {
        let caps = book.value(of: row).caps
        let clash = book.rows.clashing.contains(row.item)
        let isRecording = book.recording == row.item
        let field = SpotRoundShape(radius: SpotTokens.settingsRecordCorner)
        let ink: Color = isRecording ? .accentColor : clash ? SpotTheme.settingsClash : caps.isEmpty ? .secondary : .primary
        let rim: Color = isRecording ? .accentColor : clash ? SpotTheme.settingsClash : Color.primary.opacity(SpotTheme.settingsCapRim)
        return ZStack(alignment: .trailing) {
            Button {
                book.startRecording(row)
            } label: {
                Text(isRecording ? "Type Shortcut" : caps.isEmpty ? "Record Shortcut" : caps.joined())
                    .font(caps.isEmpty || isRecording ? SpotType.settingsLine : SpotType.settingsCap)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .frame(width: SpotTokens.settingsRecordWidth, height: SpotTokens.settingsRecordHeight)
                    .background(Color.primary.opacity(SpotTheme.settingsQuietFill), in: field)
                    .overlay(field.strokeBorder(rim, lineWidth: isRecording ? SpotTokens.settingsRecordRing : SpotTokens.settingsRim))
                    .contentShape(field)
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Press Esc to keep the shortcut, or Delete to remove it" : "Record a new shortcut")
            if !caps.isEmpty, !isRecording {
                Button { act { await $0.remove(row) } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(SpotType.settingsLine)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, SpotTokens.settingsRecordClear)
                .help("Remove the shortcut")
            }
        }
    }
}
