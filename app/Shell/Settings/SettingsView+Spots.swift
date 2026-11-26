import OpenspotCore
import SwiftUI

extension SettingsView {
    var spotsPage: some View {
        Group {
            title(of: .spots)
            ForEach(book.spots.groups) { spots in
                group(spots.id) {
                    lines(spots.standings) { spotLine($0) }
                }
            }
        }
    }

    func spotPage(of standing: SpotStanding) -> some View {
        Group {
            title(.header, SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsHeaderTile), standing.title, standing.detail) {}
            if let banner = standing.banner {
                self.banner(standing, banner.title, banner.line)
            }
            group("Permissions") {
                if standing.uses.isEmpty {
                    plain("This spot doesn’t need any permissions.")
                }
                lines(standing.uses) { useLine($0) }
            }
            ForEach(book.rows.groups(of: standing.id)) { rows in
                group(rows.id) { lines(rows.rows) { settingLine($0) } }
            }
        }
    }

    private func banner(_ standing: SpotStanding, _ title: String, _ line: String) -> some View {
        Section {
            HStack(spacing: SpotTokens.settingsRowGap) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(SpotTheme.settingsLate)
                titled(title, line)
                Spacer(minLength: SpotTokens.settingsTrailingGap)
                fix(standing)
            }
        }
    }

    private func useLine(_ use: SpotStanding.UseNeeds) -> some View {
        let accesses = use.needs.compactMap(book.access.access)
        let first = accesses.first
        return HStack(spacing: SpotTokens.settingsRowGap) {
            SettingsTile(use: use.id, access: use.needs.first, side: SpotTokens.settingsRowTile)
            Text(use.id.title)
                .lineLimit(1)
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            if let first {
                Text(first.id.title).foregroundStyle(.secondary)
                if !first.isAllowed {
                    Text(first.status.word).foregroundStyle(SpotTheme.settings(first.status))
                }
                chevron
            }
        }
        .help([use.id.purpose, use.needsLine].compactMap { $0 }.joined(separator: " "))
        .contentShape(Rectangle())
        .onTapGesture { if let first { book.go(.accessOf(first.id)) } }
        .accessibilityAddTraits(first == nil ? [] : .isButton)
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

    var keysPage: some View {
        Group {
            title(of: .keys)
            ForEach(book.keys.set) { keys in
                group(keys.id) {
                    lines(keys.rows) { keyLine($0) }
                }
            }
            if !book.keys.unset.isEmpty {
                folding("Not Set", isFolded: $isKeysFolded) {
                    ForEach(book.keys.unset) { keys in
                        DisclosureGroup(keys.id) {
                            lines(keys.rows) { keyLine($0) }
                        }
                    }
                }
            }
        }
    }

    func keyLine(_ row: SettingRow, title: String? = nil) -> some View {
        HStack(spacing: SpotTokens.settingsValueGap) {
            titled(title ?? row.title, book.keys.clash(of: row.item) ?? "")
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            keycaps(row)
        }
        .listRowBackground(book.target == row.item ? Color.accentColor.opacity(SpotTheme.settingsTarget) : nil)
        .id(row.item)
    }

    func keycaps(_ row: SettingRow) -> some View {
        let caps = book.value(of: row).caps
        let clash = book.keys.clashing.contains(row.item)
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
