import OpenspotCore
import SwiftUI

extension SettingsView {
    var accessPage: some View {
        let needed = book.access.needed
        let rest = book.access.unneeded
        return Group {
            title(.header, SettingsTile(symbol: "checkmark.shield.fill", color: SpotTheme.settings(.access), side: SpotTokens.settingsHeaderTile), SettingsPage.Section.access.title, SettingsPage.Section.access.line) {
                Button("About Access…") { isAboutShown = true }
                    .buttonStyle(.link)
            }
            if !book.spots.waiting.isEmpty {
                group("Needs Attention") {
                    lines(book.spots.waiting) { standing in
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
                            Text(access.id.title)
                                .lineLimit(1)
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            if !access.isAllowed {
                                Text(access.status.word).foregroundStyle(SpotTheme.settings(access.status))
                            }
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
                            Text(access.id.title)
                                .lineLimit(1)
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            chevron
                        }
                    }
                }
            }
        }
    }

    func accessPage(of access: AccessList.Entry) -> some View {
        let needers = access.spots.compactMap(book.spots.standing)
        let maybes = access.maybe.compactMap(book.spots.standing)
        return Group {
            title(.header, SettingsTile(access: access.id, side: SpotTokens.settingsHeaderTile), access.id.title, "\(access.id.purpose) \(access.status.sentence)") {
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
