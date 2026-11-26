import OpenspotCore
import SwiftUI

struct PageWindow<Sidebar: View, Content: View>: View {
    let title: String
    let page: String
    let reveal: CGFloat
    var target: String?
    let query: Binding<String>
    let back: (() -> Void)?
    let forward: (() -> Void)?
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content
    @State private var scroll = PageScroll()

    var body: some View {
        NavigationSplitView {
            sidebar()
                .navigationSplitViewColumnWidth(min: SpotTokens.settingsSidebarMin, ideal: SpotTokens.settingsSidebarIdeal, max: SpotTokens.settingsSidebarMax)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            ScrollViewReader { proxy in
                Form {
                    content()
                }
                .formStyle(.grouped)
                .frame(maxWidth: SpotTokens.settingsFormWidth)
                .frame(maxWidth: .infinity)
                .id(page)
                .onAppear { show(target, in: proxy) }
                .onChange(of: target) { show(target, in: proxy) }
            }
            .onChange(of: page) { scroll.reset() }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: Bool.self, of: { [reveal] in $0.contentOffset.y + $0.contentInsets.top > reveal }, action: { [scroll] _, isPast in scroll.show(title: isPast) })
            .onScrollGeometryChange(for: Bool.self, of: { $0.contentOffset.y + $0.contentInsets.top > 0 }, action: { [scroll] _, isPast in scroll.show(bar: isPast) })
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentInsets.top }, action: { [scroll] _, height in scroll.take(barHeight: height) })
            .overlay(alignment: .top) { PageScrollBar(scroll: scroll) }
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(title)
        .searchable(text: query, placement: .sidebar, prompt: "Search")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { back?() } label: { Image(systemName: "chevron.left") }
                    .disabled(back == nil)
                    .keyboardShortcut("[", modifiers: .command)
                    .help("Back")
                Button { forward?() } label: { Image(systemName: "chevron.right") }
                    .disabled(forward == nil)
                    .keyboardShortcut("]", modifiers: .command)
                    .help("Forward")
            }
            ToolbarItem(placement: .navigation) {
                PageToolbarTitle(scroll: scroll, title: title)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    private func show(_ target: String?, in proxy: ScrollViewProxy) {
        guard let target else { return }
        proxy.scrollTo(target, anchor: .center)
    }
}
