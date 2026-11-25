import OpenspotCore
import SwiftUI

extension SettingsView {
    var spotsPage: some View {
        Group {
            heading(SettingsPage.spots.section.title, SettingsPage.spots.line)
            group(nil) {
                lines(facts.standings) { spotLine($0, detail: $0.detail) }
            }
        }
    }

    func spotPage(of standing: SpotStanding) -> some View {
        Group {
            HStack(alignment: .center, spacing: SpotTokens.settingsHeaderGap) {
                SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsSpotIcon)
                VStack(alignment: .leading, spacing: SpotTokens.settingsDetailGap) {
                    Text(standing.title)
                        .font(SpotType.settingsTitle)
                    if !standing.detail.isEmpty {
                        Text(standing.detail)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: SpotTokens.settingsValueGap)
                if !standing.isOff, let entry = model.entry(standing.id) {
                    SettingsCard(model: model, entry: entry)
                }
            }
            if let banner = standing.banner {
                self.banner(standing, banner.title, banner.line)
            }
            group("Uses") {
                if standing.uses.isEmpty {
                    plain("It uses nothing of your Mac.")
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
        return HStack(spacing: SpotTokens.settingsRowGap) {
            Text(use.id.rawValue)
                .font(SpotType.settingsUse)
                .padding(.horizontal, SpotTokens.settingsUsePaddingX)
                .padding(.vertical, SpotTokens.settingsUsePaddingY)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(SpotTheme.settingsCapRim), lineWidth: SpotTokens.settingsRim))
            Text(use.id.purpose)
                .foregroundStyle(.secondary)
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            VStack(alignment: .trailing, spacing: SpotTokens.settingsTitleGap) {
                if accesses.isEmpty {
                    Text("Nothing to grant").foregroundStyle(.tertiary)
                }
                ForEach(accesses) { access in
                    HStack(spacing: SpotTokens.settingsUseGap) {
                        SettingsTile(access: access.id, side: SpotTokens.settingsUseTile)
                        Text(access.id.title + ": ") + Text(access.status.word).foregroundColor(SpotTheme.settings(access.status))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { book.go(.accessOf(access.id)) }
                }
                if !use.maybe.isEmpty {
                    Text("May ask for \(MacAccess.names(use.maybe))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, SpotTokens.settingsRowPadding)
        .padding(.vertical, SpotTokens.settingsUseRowPadding)
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
            heading(SettingsPage.keys.section.title, SettingsPage.keys.line)
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
            group(nil) {
                lines(facts.keyRows) { row in
                    HStack(spacing: SpotTokens.settingsValueGap) {
                        Text(row.name)
                            .foregroundStyle(.secondary)
                            .frame(width: SpotTokens.settingsKeyName, alignment: .leading)
                            .lineLimit(1)
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

    func keycaps(_ row: SettingRow) -> some View {
        let caps = Shortcut.caps(book.value(of: row))
        let clash = facts.clashing.contains(row.item)
        let isRecording = book.recording == row.item
        let cap = SpotRoundShape(radius: SpotTokens.settingsCapCorner)
        return Button {
            startRecording(row)
        } label: {
            if isRecording {
                Text("Type a key…")
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
        .help(isRecording ? "Esc keeps the old key" : "Record a new key")
    }
}
