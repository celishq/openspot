import AppKit
import OpenspotCore
import SwiftUI

extension SettingsView {
    var lookPage: some View {
        Group {
            heading("Look", "The theme of the panel. Each theme keeps its exact values in its own file.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: SpotTokens.settingsLookColumn), spacing: SpotTokens.settingsLookGap)], spacing: SpotTokens.settingsLookGap) {
                ForEach(facts.looks) { look in
                    VStack(spacing: SpotTokens.settingsLookWords) {
                        preview(look)
                        Text(look.id)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(look.isUsed ? "In use" : look.isBuiltIn ? "Built in" : "Yours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if !look.isUsed { act { await $0.use(theme: look.id) } } }
                    .help(look.isUsed ? "\(look.id) is in use" : "Use \(look.id)")
                }
            }
        }
    }

    private func preview(_ look: SettingsFacts.Look) -> some View {
        let swatch = scheme == .dark ? look.colours.dark : look.colours.light
        let shape = SpotRoundShape(radius: SpotTokens.settingsCorner)
        let cell = SpotRoundShape(radius: SpotTokens.settingsLookCellCorner)
        return ZStack {
            LinearGradient(colors: SpotTheme.settingsLookWall, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: SpotTokens.settingsLookCellGap) {
                Capsule().fill(swatch.ink.color.opacity(SpotTheme.settingsLookInk)).frame(height: SpotTokens.settingsLookBar)
                ForEach(0..<3) { line in
                    HStack(spacing: SpotTokens.settingsLookCellGap) {
                        ForEach(0..<3) { column in
                            cell.fill(line == 0 && column == 0 ? swatch.accent.color : swatch.ink.color.opacity(SpotTheme.settingsLookCell))
                        }
                    }
                }
            }
            .padding(SpotTokens.settingsLookPanelPadding)
            .background(swatch.background.color.opacity(SpotTheme.settingsLookPanel), in: SpotRoundShape(radius: SpotTokens.settingsLookPanelCorner))
            .padding(.horizontal, SpotTokens.settingsLookSideInset)
            .padding(.vertical, SpotTokens.settingsLookTopInset)
        }
        .frame(height: SpotTokens.settingsLookHeight)
        .clipShape(shape)
        .overlay(shape.strokeBorder(look.isUsed ? Color.accentColor : Color.primary.opacity(SpotTheme.settingsStepFill), lineWidth: look.isUsed ? SpotTokens.settingsLookRing : SpotTokens.settingsRim))
    }

    var accountPage: some View {
        let account = facts.account
        let rows = facts.rows(in: .account)
        let tile = SettingsTile(symbol: "person.crop.circle.fill", color: SpotTheme.settingsAccountTile, side: SpotTokens.settingsHeaderTile)
        return Group {
            if let account, account.isSignedIn {
                header(tile, "Account", "Your key signs each spot you publish, so people know an update is from you.") {
                    Button("How it works") { step = .how }
                        .buttonStyle(.link)
                }
                group(nil) {
                    lines(accountFacts(account)) { fact in
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
                header(tile, "Account", "You need a key to publish. Openspot signs your spots with it, so people know an update is from you.") {
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

    private struct Fact: Identifiable {
        let id: String
        let title: String
        let value: String
    }

    private func accountFacts(_ account: SettingsFacts.Account) -> [Fact] {
        [("handle", "Handle", account.handle), ("npub", "Public key", account.npub), ("since", "Since", account.since)]
            .compactMap { id, title, value in value.map { Fact(id: id, title: title, value: $0) } }
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

    func rowsPage(_ title: String, _ line: String, section: SettingsPage.Section) -> some View {
        Group {
            heading(title, line)
            group(nil) { lines(facts.rows(in: section)) { settingLine($0) } }
        }
    }
}
