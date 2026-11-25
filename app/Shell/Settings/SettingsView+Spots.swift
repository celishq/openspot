import OpenspotCore
import SwiftUI

extension SettingsView {
    var spotsPage: some View {
        Group {
            heading("Spots", "Each spot that comes with Openspot or that you added, and whether it can run.")
            group(nil) {
                lines(facts.standings) { spotLine($0, detail: $0.detail) }
            }
        }
    }

    func spotPage(of standing: SpotStanding) -> some View {
        let rows = facts.rows(of: standing.id)
        let keys = rows.filter { $0.kind == .key }
        let fields = rows.filter { [.field, .text, .secret, .choice].contains($0.kind) }
        let toggles = rows.filter { $0.kind == .toggle }
        return Group {
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
            if standing.lacks || standing.isOff {
                banner(standing)
            }
            group("Uses") {
                if standing.uses.isEmpty {
                    plain("It uses nothing of your Mac.")
                }
                lines(standing.uses) { useLine($0) }
            }
            if !keys.isEmpty {
                group("Keys") { lines(keys) { settingLine($0) } }
            }
            if !fields.isEmpty {
                group("Settings") { lines(fields) { settingLine($0) } }
            }
            if !toggles.isEmpty {
                group("Where it shows") { lines(toggles) { settingLine($0) } }
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

    private func banner(_ standing: SpotStanding) -> some View {
        let (title, line): (String, String) = switch standing.readiness {
        case .off: ("\(standing.title) is off", "It runs again once you turn it on.")
        case .review: ("\(standing.title) needs your review", SettingsWords.lack(of: standing, in: facts))
        default: ("\(standing.title) can’t run yet", "It needs \(facts.names(standing.missing)) from macOS.")
        }
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
            Text(SettingsWords.purpose(of: use.id))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            VStack(alignment: .trailing, spacing: SpotTokens.settingsTitleGap) {
                if accesses.isEmpty {
                    Text("Nothing to grant").foregroundStyle(.tertiary)
                }
                ForEach(accesses) { access in
                    HStack(spacing: SpotTokens.settingsUseGap) {
                        SettingsTile(access: access.id, side: SpotTokens.settingsUseTile)
                        Text(access.id.title + ": ") + Text(SettingsWords.word(of: access.status)).foregroundColor(SpotTheme.settings(access.status))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { book.go(.accessOf(access.id)) }
                }
                if !use.maybe.isEmpty {
                    Text("May ask for \(facts.names(use.maybe))")
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
            titled(standing.title, detail ?? (standing.lacks ? SettingsWords.lack(of: standing, in: facts) : ""))
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            if standing.lacks {
                Circle().fill(SpotTheme.settingsLate).frame(width: SpotTokens.settingsDot, height: SpotTokens.settingsDot)
            }
            Text(SettingsWords.word(of: standing.readiness)).foregroundStyle(standing.lacks ? Color.primary : Color.secondary)
            chevron
        }
    }

    var keysPage: some View {
        let keys = facts.rows.filter { $0.kind == .key }
        let shape = SpotRoundShape(radius: SpotTokens.settingsCorner)
        return Group {
            heading("Keys", "Every key of Openspot and of its spots.")
            ForEach(Array(facts.clashes.enumerated()), id: \.offset) { _, clash in
                VStack(alignment: .leading, spacing: SpotTokens.settingsDetailGap) {
                    Text(SettingsWords.caps(clash[0].value ?? "").joined() + " does \(clash.count == 2 ? "two" : "\(clash.count)") things")
                        .fontWeight(.semibold)
                    Text(clash.map { "\($0.name) · \($0.title)" }.joined(separator: " and ") + ". Change one of them.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpotTokens.settingsBannerPadding)
                .background(SpotTheme.settingsClash.opacity(SpotTheme.settingsBannerFill), in: shape)
                .overlay(shape.strokeBorder(SpotTheme.settingsClash.opacity(SpotTheme.settingsBannerRim), lineWidth: SpotTokens.settingsRim))
            }
            group(nil) {
                lines(keys) { row in
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
        let caps = SettingsWords.caps(book.value(of: row))
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
