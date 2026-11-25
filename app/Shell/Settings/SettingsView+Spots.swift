import OpenspotCore
import SwiftUI

extension SettingsView {
    var spotsPage: some View {
        Group {
            pageHeader(.spots)
            group(nil) {
                lines(facts.standings) { spotLine($0, detail: $0.detail) }
            }
        }
    }

    func spotPage(of standing: SpotStanding) -> some View {
        Group {
            header(SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsHeaderTile), standing.title, standing.detail) {} accessory: {
                if !standing.isOff, let entry = model.entry(standing.id) {
                    SettingsCard(model: model, entry: entry)
                }
            }
            if let banner = standing.banner {
                self.banner(standing, banner.title, banner.line)
            }
            group("Permissions") {
                if standing.uses.isEmpty {
                    plain("This spot doesn’t need any permissions.")
                }
                lines(standing.uses) { useLine($0) }
            }
            ForEach(facts.groups(of: standing.id)) { rows in
                group(rows.id) { lines(rows.rows) { settingLine($0) } }
            }
            HStack {
                Spacer()
                if standing.isOff {
                    Button("Turn On") { act { await $0.turn(standing.id, on: true) } }
                } else {
                    Button("Turn Off", role: .destructive) { act { await $0.turn(standing.id, on: false) } }
                }
            }
            .controlSize(.large)
        }
    }

    private func banner(_ standing: SpotStanding, _ title: String, _ line: String) -> some View {
        let shape = SpotRoundShape(radius: SpotTokens.settingsCorner)
        return HStack(spacing: SpotTokens.settingsValueGap) {
            VStack(alignment: .leading, spacing: SpotTokens.settingsDetailGap) {
                Text(title).fontWeight(.semibold)
                Text(line).foregroundStyle(.secondary)
            }
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            if standing.isOff {
                Button("Turn On") { act { await $0.turn(standing.id, on: true) } }
            } else {
                fix(standing)
            }
        }
        .padding(SpotTokens.settingsBannerPadding)
        .background(SpotTheme.settingsLate.opacity(SpotTheme.settingsBannerFill), in: shape)
        .overlay(shape.strokeBorder(SpotTheme.settingsLate.opacity(SpotTheme.settingsBannerRim), lineWidth: SpotTokens.settingsRim))
    }

    private func useLine(_ use: SpotStanding.Use) -> some View {
        let accesses = use.needs.compactMap(facts.access)
        let first = accesses.first
        return HStack(spacing: SpotTokens.settingsRowGap) {
            SettingsTile(use: use.id, access: use.needs.first, side: SpotTokens.settingsRowTile)
            VStack(alignment: .leading, spacing: SpotTokens.settingsLineGap) {
                Text(use.id.title)
                Text(use.id.purpose)
                    .font(SpotType.settingsLine)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let needs = use.needsLine {
                    Text(needs)
                        .font(SpotType.settingsLine)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            if let first {
                Text(first.status.word).foregroundStyle(SpotTheme.settings(first.status))
                chevron
            }
        }
        .padding(.horizontal, SpotTokens.settingsRowPadding)
        .padding(.vertical, SpotTokens.settingsUseRowPadding)
        .frame(minHeight: SpotTokens.settingsRowHeight)
        .contentShape(Rectangle())
        .onTapGesture { if let first { book.go(.accessOf(first.id)) } }
        .accessibilityAddTraits(first == nil ? [] : .isButton)
    }

    func spotLine(_ standing: SpotStanding, detail: String? = nil) -> some View {
        row(open: .spotOf(standing.id)) {
            SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsRowTile)
            titled(standing.title, detail ?? (standing.lacks ? standing.lack : ""))
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            if standing.lacks {
                Circle().fill(SpotTheme.settingsLate).frame(width: SpotTokens.settingsDot, height: SpotTokens.settingsDot)
            }
            Text(standing.readiness.word).foregroundStyle(standing.lacks ? Color.primary : Color.secondary)
            chevron
        }
    }

    var keysPage: some View {
        let shape = SpotRoundShape(radius: SpotTokens.settingsCorner)
        return Group {
            pageHeader(.keys)
            ForEach(Array(facts.clashes.enumerated()), id: \.offset) { _, clash in
                VStack(alignment: .leading, spacing: SpotTokens.settingsDetailGap) {
                    Text(clash.title)
                        .fontWeight(.semibold)
                    Text(clash.line)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpotTokens.settingsBannerPadding)
                .background(SpotTheme.settingsClash.opacity(SpotTheme.settingsBannerFill), in: shape)
                .overlay(shape.strokeBorder(SpotTheme.settingsClash.opacity(SpotTheme.settingsBannerRim), lineWidth: SpotTokens.settingsRim))
            }
            ForEach(facts.keyGroups) { keys in
                group(keys.id) {
                    lines(keys.rows) { row in
                        HStack(spacing: SpotTokens.settingsValueGap) {
                            Text(row.title)
                                .lineLimit(1)
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            keycaps(row)
                        }
                        .padding(.horizontal, SpotTokens.settingsRowPadding)
                        .frame(minHeight: SpotTokens.settingsLineHeight)
                        .background(book.target == row.item ? Color.accentColor.opacity(SpotTheme.settingsTarget) : .clear)
                        .id(row.item)
                    }
                }
            }
        }
    }

    func keycaps(_ row: SettingRow) -> some View {
        let caps = Shortcut.caps(book.value(of: row))
        let clash = facts.clashing.contains(row.item)
        let isRecording = book.recording == row.item
        let cap = SpotRoundShape(radius: SpotTokens.settingsCapCorner)
        return HStack(spacing: SpotTokens.settingsCapGap) {
            Button {
                book.startRecording(row)
            } label: {
                if isRecording {
                    Text("Type Shortcut")
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, SpotTokens.settingsRecordPadding)
                        .frame(height: SpotTokens.settingsRecordHeight)
                        .overlay(SpotRoundShape(radius: SpotTokens.settingsRecordCorner).strokeBorder(Color.accentColor, lineWidth: 1))
                } else if caps.isEmpty {
                    Text("Not set").foregroundStyle(.secondary)
                } else {
                    HStack(spacing: SpotTokens.settingsCapGap) {
                        ForEach(Array(caps.enumerated()), id: \.offset) { _, word in
                            Text(word)
                                .font(SpotType.settingsCap)
                                .foregroundStyle(clash ? SpotTheme.settingsClash : Color.primary)
                                .padding(.horizontal, SpotTokens.settingsCapPadding)
                                .frame(minWidth: SpotTokens.settingsCapWidth, minHeight: SpotTokens.settingsCapHeight)
                                .background(Color.primary.opacity(SpotTheme.settingsQuietFill), in: cap)
                                .overlay(cap.strokeBorder(clash ? SpotTheme.settingsClash : Color.primary.opacity(SpotTheme.settingsCapRim), lineWidth: SpotTokens.settingsRim))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Press Esc to keep the shortcut, or Delete to remove it" : "Record a new shortcut")
            if !caps.isEmpty, !isRecording {
                Button { act { await $0.remove(row) } } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Remove the shortcut")
            }
        }
    }
}
