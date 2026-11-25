import OpenspotCore
import SwiftUI

extension SettingsView {
    var spotsPage: some View {
        Group {
            pageHeader(.spots)
            ForEach(facts.spotGroups) { spots in
                group(spots.id) {
                    lines(spots.standings) { spotLine($0) }
                }
            }
        }
    }

    func spotPage(of standing: SpotStanding) -> some View {
        Group {
            header(SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsHeaderTile), standing.title, standing.detail) {}
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
            Section {
                HStack {
                    titled(standing.isOff ? "This spot is off" : "Turn off this spot", standing.isOff ? "It doesn’t show in the panel or run." : "It stops showing in the panel and stops running.")
                    Spacer(minLength: SpotTokens.settingsTrailingGap)
                    if standing.isOff {
                        Button("Turn On") { act { await $0.turn(standing.id, on: true) } }
                    } else {
                        Button("Turn Off", role: .destructive) { act { await $0.turn(standing.id, on: false) } }
                    }
                }
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
                if standing.isOff {
                    Button("Turn On") { act { await $0.turn(standing.id, on: true) } }
                } else {
                    fix(standing)
                }
            }
        }
    }

    private func useLine(_ use: SpotStanding.Use) -> some View {
        let accesses = use.needs.compactMap(facts.access)
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
            } else if standing.isOff {
                Text(standing.readiness.word).foregroundStyle(.secondary)
            }
            chevron
        }
    }

    var keysPage: some View {
        Group {
            pageHeader(.keys)
            if !facts.clashes.isEmpty {
                Section {
                    ForEach(Array(facts.clashes.enumerated()), id: \.offset) { _, clash in
                        HStack(spacing: SpotTokens.settingsRowGap) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(SpotTheme.settingsClash)
                            titled(clash.title, clash.line)
                        }
                    }
                }
            }
            Section {
                HStack {
                    if let adding = book.recording.flatMap(facts.row), (adding.value ?? "").isEmpty {
                        Text("\(adding.name) · \(adding.title)")
                        Spacer(minLength: SpotTokens.settingsTrailingGap)
                        keycaps(adding)
                    } else {
                        Text("Give a spot or a command its own shortcut.").foregroundStyle(.secondary)
                        Spacer(minLength: SpotTokens.settingsTrailingGap)
                        Menu("Add Shortcut…") {
                            ForEach(facts.unsetKeys) { keys in
                                Menu(keys.id) {
                                    ForEach(keys.rows) { row in
                                        Button(row.title) { book.startRecording(row) }
                                    }
                                }
                            }
                        }
                        .fixedSize()
                        .disabled(facts.unsetKeys.isEmpty)
                    }
                }
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
                        .listRowBackground(book.target == row.item ? Color.accentColor.opacity(SpotTheme.settingsTarget) : nil)
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
                    Text("Record Shortcut")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, SpotTokens.settingsRecordPadding)
                        .frame(height: SpotTokens.settingsRecordHeight)
                        .overlay(SpotRoundShape(radius: SpotTokens.settingsRecordCorner).strokeBorder(Color.primary.opacity(SpotTheme.settingsCapRim), lineWidth: SpotTokens.settingsRim))
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
