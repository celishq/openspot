import OpenspotCore
import SwiftUI

extension SettingsView {
    var accessPage: some View {
        let needed = book.access.needed
        let rest = book.access.unneeded
        return Group {
            title(.header, SettingsTile(symbol: "checkmark.shield.fill", color: SpotTheme.settings(.access), side: SpotTokens.settingsHeaderTile), SettingsPage.Section.access.title, SettingsPage.Section.access.line) {
                Button("How Access Works…") { isAboutShown = true }
                    .buttonStyle(.link)
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
        VStack(alignment: .leading, spacing: SpotTokens.settingsSheetGap) {
            VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                Text("How access works")
                    .font(SpotType.settingsTitle)
                Text("A spot uses a feature of your Mac only through Openspot, and only after you allow it once.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: SpotTokens.settingsRowGap) {
                ForEach(MacAccess.about, id: \.symbol) { fact in
                    aboutLine(Image(systemName: fact.symbol).foregroundStyle(.secondary), Text(fact.text))
                }
            }
            VStack(alignment: .leading, spacing: SpotTokens.settingsRowGap) {
                ForEach(SpotReadiness.allCases, id: \.self) { state in
                    aboutLine(
                        Circle().fill(SpotTheme.settingsState(state)).frame(width: SpotTokens.settingsDot, height: SpotTokens.settingsDot),
                        Text("\(Text(state.word).fontWeight(.medium))  \(Text(state.line).foregroundStyle(.secondary))")
                    )
                }
            }
            HStack {
                Spacer()
                Button("Done") { isAboutShown = false }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, SpotTokens.settingsSheetTop)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(SpotTokens.settingsSheetPadding)
        .frame(width: SpotTokens.settingsSheetWidth, alignment: .leading)
    }

    private func aboutLine(_ mark: some View, _ words: Text) -> some View {
        HStack(spacing: SpotTokens.settingsRowGap) {
            mark.frame(width: SpotTokens.settingsRowTile)
            words
        }
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
