import AppKit
import OpenspotCore
import SwiftUI

extension SettingsView {
    var accountPage: some View {
        let account = book.account
        return Group {
            if let account, account.signedIn {
                title(.hero, PublisherCard(account: account) { copy(account.npub ?? "") }, "", AccountStatus.line, link: PageLink(title: "How It Works…") { step = .how }) {}
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
                Section {
                    HStack {
                        titled("Sign out", "Removes your key from this Mac.")
                        Spacer(minLength: SpotTokens.settingsValueGap)
                        Button("Sign Out…") { step = .leave }
                    }
                }
            } else {
                title(.hero, PublisherCard(account: nil) { step = .handle }, "Sign In to Publish", AccountStatus.line, link: PageLink(title: "How It Works…") { step = .how }) {
                    Button("Use My Own Key…") { step = .signIn }
                }
            }
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
        try? SpotClipboard().copy(text: npub)
        book.say("Copied your key")
    }
}
