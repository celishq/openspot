import AppKit
import OpenspotCore
import SwiftUI

extension SettingsView {
    var accountPage: some View {
        let account = facts.account
        let rows = facts.rows(in: .account)
        let tile = SettingsTile(symbol: "person.crop.circle.fill", color: SpotTheme.settingsAccountTile, side: SpotTokens.settingsHeaderTile)
        return Group {
            if let account, account.isSignedIn {
                header(tile, SettingsPage.account.section.title, SettingsPage.account.line) {
                    Button("How it works") { step = .how }
                        .buttonStyle(.link)
                }
                group(nil) {
                    lines(account.lines) { fact in
                        HStack {
                            Text(fact.title)
                            Spacer(minLength: SpotTokens.settingsValueGap)
                            Text(fact.value)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            if fact.id == "npub" {
                                Button("Copy") { copy(fact.value) }
                            }
                        }
                        .padding(.horizontal, SpotTokens.settingsRowPadding)
                        .frame(minHeight: SpotTokens.settingsLineHeight)
                    }
                }
                group("Backup") {
                    if let sync = account.sync {
                        HStack {
                            titled("Keep in iCloud Keychain", "Your other Macs sign in with it.")
                            Spacer(minLength: SpotTokens.settingsValueGap)
                            Toggle("", isOn: Binding(get: { sync }, set: { isOn in act { await $0.sync(isOn) } }))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .controlSize(.small)
                        }
                        .padding(.horizontal, SpotTokens.settingsRowPadding)
                        .frame(minHeight: SpotTokens.settingsLineHeight)
                        Divider().padding(.leading, SpotTokens.settingsRowPadding)
                    }
                    HStack {
                        titled("Recovery words", "12 words bring your key back on any Mac.")
                        Spacer(minLength: SpotTokens.settingsValueGap)
                        saved(account)
                        Button("Show My Words…") { step = .words }
                    }
                    .padding(.horizontal, SpotTokens.settingsRowPadding)
                    .frame(minHeight: SpotTokens.settingsRowHeight)
                }
                if !rows.isEmpty {
                    group(nil) { lines(rows) { settingLine($0) } }
                }
                HStack {
                    Spacer()
                    Button("Sign Out…") { step = .leave }
                }
                .controlSize(.large)
            } else {
                header(tile, SettingsPage.account.section.title, "You need a key to publish. " + SettingsPage.account.line) {
                    HStack(spacing: SpotTokens.settingsRowGap) {
                        Button("Create a New Key…") { step = .handle }
                            .buttonStyle(.borderedProminent)
                        Button("Use My Own Key…") { step = .signIn }
                        Button("How it works") { step = .how }
                            .buttonStyle(.link)
                    }
                    .padding(.top, SpotTokens.settingsSheetTop)
                }
            }
        }
    }

    @ViewBuilder
    private func saved(_ account: SettingsFacts.Account) -> some View {
        if account.isBackedUp {
            Text("Saved").foregroundStyle(SpotTheme.settingsDone)
        } else if account.sync == true {
            Text("In iCloud Keychain").foregroundStyle(.secondary)
        } else {
            Text("Not saved yet").foregroundStyle(SpotTheme.settingsLate)
        }
    }

    private func copy(_ npub: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(npub, forType: .string)
        book.say("Copied your key")
    }
}
