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
            reveal: reveal,
            target: book.target,
            query: Binding(get: { book.query }, set: { book.search($0) }),
            back: book.back.isEmpty ? nil : { book.goBack() },
            forward: book.forward.isEmpty ? nil : { book.goForward() }
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
        case .access, .accessOf, .spotOf: PageTitle.header.reveal
        default: PageTitle.heading.reveal
        }
    }

    private var sidebar: some View {
        List(selection: chosen) {
            ForEach(SettingsPage.Section.sidebar) { section in
                let count = section == .general ? book.spots.waiting.count : 0
                HStack(spacing: SpotTokens.settingsGroupGap) {
                    SettingsTile(symbol: section.symbol, color: SpotTheme.settings(section), side: SpotTokens.settingsSectionTile)
                    Text(section.title)
                    Spacer(minLength: 0)
                    if count > 0 {
                        Text("\(count)")
                            .font(SpotType.settingsBadge)
                            .foregroundStyle(SpotTheme.settingsBadgeInk)
                            .frame(minWidth: SpotTokens.settingsBadge, minHeight: SpotTokens.settingsBadge)
                            .background(SpotTheme.settingsBadge, in: Circle())
                    }
                }
                .tag(SettingsMark.section(section))
            }
            if !book.shownSpots.isEmpty {
                Section("Spots") {
                    ForEach(book.shownSpots) { standing in
                        HStack(spacing: SpotTokens.settingsGroupGap) {
                            SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsSectionTile)
                            Text(standing.title)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if standing.lacks {
                                Circle().fill(SpotTheme.settingsLate).frame(width: SpotTokens.settingsDot, height: SpotTokens.settingsDot)
                            }
                        }
                        .tag(SettingsMark.spot(standing.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .tint(SpotTheme.settingsSelection)
        .safeAreaInset(edge: .top) { accountRow }
    }

    private var accountRow: some View {
        let isChosen = book.query.isEmpty && book.mark == .section(.account)
        let account = book.account
        return HStack(spacing: SpotTokens.settingsGroupGap) {
            SettingsAvatar(side: SpotTokens.settingsAccountTile)
            VStack(alignment: .leading, spacing: SpotTokens.settingsLineGap) {
                Text(account?.signedIn == true ? account?.handle.map { "@\($0)" } ?? "Account" : "Sign In")
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("Account")
                    .font(SpotType.settingsLine)
                    .foregroundStyle(isChosen ? SpotTheme.settingsSelectedInk : Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isChosen ? SpotTheme.settingsSelectedInk : Color.primary)
        .padding(SpotTokens.settingsAccountPadding)
        .background(isChosen ? SpotTheme.settingsSelection : Color.clear, in: SpotRoundShape(radius: SpotTokens.settingsAccountCorner))
        .contentShape(Rectangle())
        .onTapGesture { book.go(.account) }
        .accessibilityAddTraits(.isButton)
        .padding(SpotTokens.settingsAccountInset)
    }

    private var chosen: Binding<SettingsMark?> {
        Binding(
            get: { book.query.isEmpty ? book.mark : nil },
            set: { mark in
                switch mark {
                case .section(let section): book.go(.top(section))
                case .spot(let id): book.go(.spotOf(id))
                case nil: break
                }
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        if book.isSearching {
            results
        } else {
            switch book.page {
            case .top(.access): accessPage
            case .top(.general): generalPage
            case .top(.look): lookPage
            case .top(.account): accountPage
            case .top(let section): rowsPage(section)
            case .accessOf(let id): book.access.access(id).map { accessPage(of: $0) }
            case .spotOf(let id): book.spots.standing(id).map { spotPage(of: $0) }
            case .row, .search: EmptyView()
            }
        }
    }

    func act(_ work: @escaping @MainActor (SettingsBook) async -> Void) {
        let book = book
        Task { await work(book) }
    }
}
