import AppKit
import OpenspotCore
import SwiftUI

struct SettingsView: View {
    let model: SpotsModel
    @State var isFolded = true
    @State var isAboutShown = false
    @State var drafts: [String: String] = [:]
    @State var step: SettingsAccountSheet.Step?
    @State private var scroll = SettingsScroll()

    var book: SettingsBook {
        model.settingsBook
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: SpotTokens.settingsSidebarMin, ideal: SpotTokens.settingsSidebarIdeal, max: SpotTokens.settingsSidebarMax)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            ScrollViewReader { proxy in
                Form {
                    content
                }
                .formStyle(.grouped)
                .frame(maxWidth: SpotTokens.settingsFormWidth)
                .frame(maxWidth: .infinity)
                .id(shown)
                .onAppear { reveal(in: proxy) }
                .onChange(of: book.target) { reveal(in: proxy) }
            }
            .onChange(of: shown) { scroll.reset() }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: Bool.self, of: { [reveal] in $0.contentOffset.y + $0.contentInsets.top > reveal }, action: { [scroll] _, isPast in scroll.show(title: isPast) })
            .onScrollGeometryChange(for: Bool.self, of: { $0.contentOffset.y + $0.contentInsets.top > 0 }, action: { [scroll] _, isPast in scroll.show(bar: isPast) })
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentInsets.top }, action: { [scroll] _, height in scroll.take(barHeight: height) })
            .overlay(alignment: .top) { SettingsScrollBar(scroll: scroll) }
            .onChange(of: book.recording == nil) { _, isIdle in HotKey.pause(!isIdle) }
            .onDisappear { HotKey.pause(false) }
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(book.title)
        .searchable(text: Binding(get: { book.query }, set: { book.search($0) }), placement: .sidebar, prompt: "Search")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { book.goBack() } label: { Image(systemName: "chevron.left") }
                    .disabled(book.back.isEmpty)
                    .help("Back")
                Button { book.goForward() } label: { Image(systemName: "chevron.right") }
                    .disabled(book.forward.isEmpty)
                    .help("Forward")
            }
            ToolbarItem(placement: .navigation) {
                SettingsToolbarTitle(scroll: scroll, title: book.title)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .overlay { book.grant.map { SettingsGrantSheet(book: book, grant: $0) } }
        .sheet(isPresented: $isAboutShown) { about }
        .sheet(isPresented: Binding(get: { step != nil }, set: { if !$0 { step = nil } })) { SettingsAccountSheet(book: book, step: $step) }
    }

    private var shown: String {
        book.isSearching ? "search/\(book.query)" : book.page.place
    }

    private func reveal(in proxy: ScrollViewProxy) {
        guard let target = book.target else { return }
        proxy.scrollTo(target, anchor: .center)
    }

    private var reveal: CGFloat {
        SettingsTitle(page: book.page, isSearching: book.isSearching).reveal
    }

    private var sidebar: some View {
        List(selection: chosen) {
            ForEach(SettingsPage.Section.allCases.filter { $0 != .account }) { section in
                let count = section == .access ? book.spots.waiting.count : 0
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
                .tag(section)
            }
        }
        .listStyle(.sidebar)
        .tint(SpotTheme.settingsSelection)
        .safeAreaInset(edge: .bottom) { accountRow }
    }

    private var accountRow: some View {
        let isChosen = book.query.isEmpty && book.page.section == .account
        let account = book.account
        return HStack(spacing: SpotTokens.settingsGroupGap) {
            SettingsAvatar(side: SpotTokens.settingsAccountTile)
            VStack(alignment: .leading, spacing: SpotTokens.settingsLineGap) {
                Text(account?.signedIn == true ? account?.handle.map { "@\($0)" } ?? "Account" : "Sign In")
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(account?.signedIn == true ? "Account" : "Publish your spots")
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

    private var chosen: Binding<SettingsPage.Section?> {
        Binding(
            get: { book.query.isEmpty ? book.page.section : nil },
            set: { if let section = $0 { book.go(section.page) } }
        )
    }

    @ViewBuilder
    private var content: some View {
        if book.isSearching {
            results
        } else {
            switch book.page {
            case .access: accessPage
            case .accessOf(let id): book.access.access(id).map { accessPage(of: $0) }
            case .spots: spotsPage
            case .spotOf(let id): book.spots.standing(id).map { spotPage(of: $0) }
            case .keys: keysPage
            case .look: lookPage
            case .account: accountPage
            case .general: rowsPage(.general)
            case .developer: rowsPage(.developer)
            case .row, .search: EmptyView()
            }
        }
    }

    func act(_ work: @escaping @MainActor (SettingsBook) async -> Void) {
        let book = book
        Task { await work(book) }
    }
}
