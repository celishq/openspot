import OpenspotCore
import SwiftUI

extension SettingsView {
    var accessPage: some View {
        let needed = facts.needed
        let rest = facts.unneeded
        return Group {
            header(SettingsTile(symbol: "checkmark.shield.fill", color: SpotTheme.settings(.access), side: SpotTokens.settingsHeaderTile), SettingsPage.access.section.title, SettingsPage.access.line) {
                Button("About Access…") { isAboutShown = true }
                    .buttonStyle(.link)
            }
            if !facts.waiting.isEmpty {
                group("Needs Attention") {
                    lines(facts.waiting) { standing in
                        row(open: .spotOf(standing.id)) {
                            SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsRowTile)
                            titled(standing.title, standing.lack)
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            fix(standing)
                        }
                    }
                }
            }
            if !needed.isEmpty {
                group("Privacy & Security") {
                    lines(needed) { access in
                        row(open: .accessOf(access.id)) {
                            SettingsTile(access: access.id, side: SpotTokens.settingsRowTile)
                            titled(access.id.title, access.spots.map(facts.title(ofSpot:)).joined(separator: ", "))
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            Text(access.status.word).foregroundStyle(SpotTheme.settings(access.status))
                            chevron
                        }
                    }
                }
            }
            if !rest.isEmpty {
                folding("Not Used by Any Spot", isFolded: $isFolded) {
                    lines(rest) { access in
                        row(open: .accessOf(access.id)) {
                            SettingsTile(access: access.id, side: SpotTokens.settingsRowTile)
                            titled(access.id.title, access.maybe.isEmpty ? "" : "Sometimes used by " + access.maybe.map(facts.title(ofSpot:)).joined(separator: ", "))
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            Text(access.status.word).foregroundStyle(.secondary)
                            chevron
                        }
                    }
                }
            }
        }
    }

    func accessPage(of access: AccessList.Entry) -> some View {
        let needers = access.spots.compactMap(facts.standing)
        let maybes = access.maybe.compactMap(facts.standing)
        return Group {
            header(SettingsTile(access: access.id, side: SpotTokens.settingsHeaderTile), access.id.title, "\(access.id.purpose) \(access.status.sentence)") {
                if !access.isAllowed {
                    Button("Allow…") { act { await $0.ask(access.id) } }
                        .controlSize(.large)
                        .padding(.top, SpotTokens.settingsTitleGap)
                }
            }
            group("Spots Using This") {
                if needers.isEmpty {
                    plain("No spots use this access.")
                }
                lines(needers) { spotLine($0) }
            }
            if !maybes.isEmpty {
                group("Spots That May Ask") {
                    lines(maybes) { spotLine($0) }
                }
            }
        }
    }

    var about: some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsValueGap) {
            Text("About access")
                .font(SpotType.settingsTitle)
            ForEach(MacAccess.about, id: \.self) { Text($0) }
            HStack {
                Spacer()
                Button("Done") { isAboutShown = false }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, SpotTokens.settingsSheetTop)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(SpotTokens.settingsSheetPadding)
        .frame(width: SpotTokens.settingsSheetWidth)
    }

    @ViewBuilder
    func fix(_ standing: SpotStanding) -> some View {
        if standing.readiness == .review, let use = standing.refused.first {
            Button("Review…") { act { await $0.review(standing.id, use: use) } }
        } else {
            Button("Allow…") { act { await $0.allow(standing.id) } }
        }
    }
}
