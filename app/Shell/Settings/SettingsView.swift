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
    @FocusState private var isListening: Bool
    @Environment(\.colorScheme) var scheme

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
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: SpotTokens.settingsPageGap) {
                            content
                        }
                        .padding(SpotTokens.settingsPagePadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onScrollGeometryChange(for: Bool.self, of: { $0.contentOffset.y + $0.contentInsets.top > SpotTokens.settingsTitleReveal }, action: { _, isPast in
                        withAnimation(SpotMotion.fade(isShown: isPast)) { isTitleShown = isPast }
                    })
                    .onChange(of: book.target) {
                        guard let target = book.target else { return }
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
                Divider()
                SpotWindowFooter(hint: book.hint, tip: "Close Settings") {}
            }
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
        .focusable()
        .focusEffectDisabled()
        .focused($isListening)
        .onKeyPress(phases: .down) { press in record(press) }
        .overlay { book.grant.map { SettingsGrantSheet(book: book, grant: $0) } }
        .sheet(isPresented: $isAboutShown) { about }
        .sheet(isPresented: Binding(get: { step != nil }, set: { if !$0 { step = nil } })) { SettingsAccountSheet(book: book, step: $step) }
    }

    private var sidebar: some View {
        List(selection: chosen) {
            ForEach(SettingsPage.Section.allCases) { section in
                let count = section == .access ? facts.waiting.count : 0
                HStack(spacing: SpotTokens.settingsGroupGap) {
                    SettingsTile(symbol: section.symbol, color: SpotTheme.settings(section), side: SpotTokens.settingsSectionTile)
                    Text(section.rawValue)
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
            case .general: rowsPage("General", "The keys that open Openspot, and how it starts.", section: .general)
            case .developer: rowsPage("Developer", "For those who build spots and themes.", section: .developer)
            }
        }
    }

    func startRecording(_ row: SettingRow) {
        book.startRecording(row)
        isListening = true
    }

    private func record(_ press: KeyPress) -> KeyPress.Result {
        guard book.recording != nil else { return .ignored }
        let modifiers = [(EventModifiers.command, "cmd"), (EventModifiers.control, "ctrl"), (EventModifiers.option, "option"), (EventModifiers.shift, "shift")]
            .filter { press.modifiers.contains($0.0) }.map(\.1)
        return book.record(key: Self.name(of: press.key), modifiers: modifiers) ? .handled : .ignored
    }

    private static func name(of key: KeyEquivalent) -> String {
        switch key {
        case .space: "space"
        case .return: "return"
        case .tab: "tab"
        case .delete: "backspace"
        case .escape: "escape"
        case .leftArrow: "left"
        case .rightArrow: "right"
        case .upArrow: "up"
        case .downArrow: "down"
        default: String(key.character).lowercased()
        }
    }

    func act(_ work: @escaping @MainActor (SettingsBook) async -> Void) {
        let book = book
        Task { await work(book) }
    }
}
