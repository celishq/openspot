import AppKit
import OpenspotCore
import SwiftUI

extension SettingsView {
    var accountPage: some View {
        let account = book.account
        let rows = book.rows.rows(in: .account)
        return Group {
            if let account, account.signedIn {
                hero(account.handle.map { "@\($0)" } ?? SettingsPage.account.section.title, SettingsPage.account.line) {
                    Button("How It Works…") { step = .how }
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
                    }
                    HStack {
                        titled("Recovery words", "12 words bring your key back on any Mac.")
                        Spacer(minLength: SpotTokens.settingsValueGap)
                        saved(account)
                        Button("Show My Words…") { step = .words }
                    }
                }
                if !rows.isEmpty {
                    group(nil) { lines(rows) { settingLine($0) } }
                }
                Section {
                    HStack {
                        titled("Sign out", "Removes your key from this Mac.")
                        Spacer(minLength: SpotTokens.settingsValueGap)
                        Button("Sign Out…") { step = .leave }
                    }
                }
            } else {
                hero("Sign In to Publish", SettingsPage.account.line) {
                    HStack(spacing: SpotTokens.settingsRowGap) {
                        Button("Use My Own Key…") { step = .signIn }
                        Button("Create a New Key…") { step = .handle }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, SpotTokens.settingsSheetTop)
                    Button("How It Works…") { step = .how }
                        .buttonStyle(.link)
                }
            }
        }
    }

    private func hero<Actions: View>(_ title: String, _ line: String, @ViewBuilder actions: () -> Actions) -> some View {
        Section {} header: {
            VStack(spacing: SpotTokens.settingsHeroGap) {
                SettingsAvatar(side: SpotTokens.settingsHeroAvatar)
                Text(title)
                    .font(SpotType.settingsHero)
                    .foregroundStyle(.primary)
                Text(line)
                    .font(SpotType.settingsPageLine)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                actions()
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, SpotTokens.settingsHeadingGap)
            .textCase(nil)
        }
    }

    @ViewBuilder
    private func saved(_ account: AccountStatus) -> some View {
        if account.backedUp == true {
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
