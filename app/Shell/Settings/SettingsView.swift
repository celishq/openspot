import AppKit
import OpenspotCore
import SwiftUI

struct SettingsView: PageView {
    let model: SpotsModel
    @Environment(\.colorScheme) var colorScheme
    @State var isFolded = true
    @State var isAboutShown = false
    @State var isThemeAsked = false
    @State var themeWish = ""
    @State var isThemeCopied = false
    @State var drafts: [String: String] = [:]
    @State var step: SettingsAccountSheet.Step?

    var book: SettingsBook {
        model.settingsBook
    }

    var body: some View {
        PageWindow(
            title: book.title,
            page: shown,
            visit: book.trail.now.visit,
            reveal: reveal,
            target: book.target,
            query: Binding(get: { book.query }, set: { book.search($0) }),
            back: book.trail.back.isEmpty ? nil : { book.goBack() },
            forward: book.trail.forward.isEmpty ? nil : { book.goForward() }
        ) {
            sidebar
        } content: {
            content
        }
        .onChange(of: book.recording == nil) { _, isIdle in HotKey.pause(!isIdle) }
        .onDisappear { HotKey.pause(false) }
        .overlay { book.grant.map { SettingsGrantSheet(book: book, grant: $0) } }
        .sheet(isPresented: $isAboutShown) { about }
        .sheet(isPresented: $isThemeAsked) { themeForm }
        .sheet(isPresented: Binding(get: { step != nil }, set: { if !$0 { step = nil } })) { SettingsAccountSheet(book: book, step: $step) }
    }

    private var shown: String {
        book.isSearching ? "search/\(book.query)" : book.page.place
    }

    private var reveal: CGFloat {
        switch book.page {
        case _ where book.isSearching: PageTitle.heading.reveal
        case .account: PageTitle.hero.reveal
        case .accessOf, .spotOf: PageTitle.header.reveal
        case .top: PageTitle.banner.reveal
        }
    }

    private var sidebar: some View {
        List(selection: chosen) {
            accountRow
                .tag(SettingsPage.account)
            ForEach(SettingsPage.Section.allCases) { section in
                let count = section == .general ? book.spots.waiting.count : 0
                PageSidebarRow(title: section.title) {
                    SettingsTile(symbol: section.symbol, color: SpotTheme.settings(section), side: SpotTokens.settingsSectionTile)
                } trailing: {
                    if count > 0 {
                        Text("\(count)")
                            .font(SpotType.settingsBadge)
                            .foregroundStyle(SpotTheme.settingsBadgeInk)
                            .frame(minWidth: SpotTokens.settingsBadge, minHeight: SpotTokens.settingsBadge)
                            .background(SpotTheme.settingsBadge, in: Circle())
                    }
                }
                .tag(SettingsPage.top(section))
            }
            if !book.shownSpots.isEmpty {
                Section("Spots") {
                    ForEach(book.shownSpots) { standing in
                        PageSidebarRow(title: standing.title) {
                            SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsSectionTile)
                        } trailing: {
                            if standing.lacks {
                                Circle().fill(SpotTheme.settingsLate).frame(width: SpotTokens.settingsDot, height: SpotTokens.settingsDot)
                            }
                        }
                        .tag(SettingsPage.spotOf(standing.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .tint(SpotTheme.settingsSelection)
    }

    private var accountRow: some View {
        let account = book.account
        return HStack(spacing: SpotTokens.settingsGroupGap) {
            SettingsAvatar(side: SpotTokens.settingsAccountTile)
            VStack(alignment: .leading, spacing: SpotTokens.settingsLineGap) {
                Text(account?.signedIn == true ? account?.handle.map { "@\($0)" } ?? "Account" : "Sign In")
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("Account")
                    .font(SpotType.settingsLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, SpotTokens.settingsAccountPadding / 2)
    }

    private var chosen: Binding<SettingsPage?> {
        Binding(
            get: { book.query.isEmpty ? book.mark : nil },
            set: { if let page = $0 { book.go(page) } }
        )
    }

    @ViewBuilder
    private var content: some View {
        if book.isSearching {
            results
        } else {
            switch book.page {
            case .top(.access): accessPage
            case .top(.general): sectionPage(.general, rowsTitle: "Openspot") { needsYou }
            case .top(.look): lookPage
            case .account: accountPage
            case .top(let section): sectionPage(section)
            case .accessOf(let id): book.access.access(id).map { accessPage(of: $0) }
            case .spotOf(let id): book.spots.standing(id).map { spotPage(of: $0) }
            }
        }
    }

    func act(_ work: @escaping @MainActor (SettingsBook) async -> Void) {
        let book = book
        Task { await work(book) }
    }
}
