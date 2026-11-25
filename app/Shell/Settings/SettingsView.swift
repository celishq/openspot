import AppKit
import OpenspotCore
import SwiftUI

struct SettingsView: View {
    let model: SpotsModel
    @State var isFolded = true
    @State var isAboutShown = false
    @State var drafts: [String: String] = [:]
    @State var step: SettingsAccountSheet.Step?
    @State private var isTitleShown = false
    @State private var isScrolled = false
    @State private var barHeight: CGFloat = 0
    @Environment(\.colorScheme) var scheme

    static let top = "settings-top"

    var book: SettingsBook {
        model.settingsBook
    }

    var facts: SettingsFacts {
        book.facts
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
                .onChange(of: [book.page.place, book.query, book.target]) {
                    proxy.scrollTo(book.target ?? Self.top, anchor: book.target == nil ? .top : .center)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: Bool.self, of: { [reveal] in $0.contentOffset.y + $0.contentInsets.top > reveal }, action: { _, isPast in
                withAnimation(SpotMotion.fade(isShown: isPast)) { isTitleShown = isPast }
            })
            .onScrollGeometryChange(for: Bool.self, of: { $0.contentOffset.y + $0.contentInsets.top > 0 }, action: { _, isPast in
                withAnimation(SpotMotion.fade(isShown: isPast)) { isScrolled = isPast }
            })
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentInsets.top }, action: { _, height in barHeight = height })
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.bar)
                    .mask {
                        VStack(spacing: 0) {
                            Rectangle()
                            LinearGradient(colors: SpotTheme.settingsBarFade, startPoint: .top, endPoint: .bottom)
                                .frame(height: SpotTokens.settingsBarFade)
                        }
                    }
                    .frame(height: barHeight + SpotTokens.settingsBarFade)
                    .offset(y: -barHeight)
                    .opacity(isScrolled ? 1 : MotionTokens.hiddenOpacity)
                    .allowsHitTesting(false)
            }
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
                Text(book.title)
                    .font(SpotType.settingsPageTitle)
                    .lineLimit(1)
                    .opacity(isTitleShown ? 1 : MotionTokens.hiddenOpacity)
                    .allowsHitTesting(isTitleShown)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .overlay { book.grant.map { SettingsGrantSheet(book: book, grant: $0) } }
        .sheet(isPresented: $isAboutShown) { about }
        .sheet(isPresented: Binding(get: { step != nil }, set: { if !$0 { step = nil } })) { SettingsAccountSheet(book: book, step: $step) }
    }

    private var reveal: CGFloat {
        switch book.page {
        case .access, .accessOf, .spotOf, .account: SpotTokens.settingsTitleReveal
        default: SpotTokens.settingsHeadingReveal
        }
    }

    private var sidebar: some View {
        List(selection: chosen) {
            ForEach(SettingsPage.Section.allCases) { section in
                let count = section == .access ? facts.waiting.count : 0
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
            case .accessOf(let id): facts.access(id).map { accessPage(of: $0) }
            case .spots: spotsPage
            case .spotOf(let id): facts.standing(id).map { spotPage(of: $0) }
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
