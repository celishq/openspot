import AppKit
import OpenspotCore
import SwiftUI

struct StoreSidebar: View {
    let store: Store
    let drag: StoreDrag
    @State private var isAdding = false

    var body: some View {
        List(selection: Binding(get: { store.place }, set: { if let place = $0 { store.choose(place) } })) {
            mine
                .tag(StorePlace.mine)
                .simultaneousGesture(TapGesture().onEnded { leavePage(at: .mine) })
            Section("Stores") {
                ForEach(store.sources, id: \.self) { source in
                    sourceRow(source)
                        .tag(StorePlace.source(source))
                        .simultaneousGesture(TapGesture().onEnded { leavePage(at: .source(source)) })
                        .contextMenu {
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([source.url]) }
                            if source.canRemove {
                                Button("Remove Store") { Task { await store.removeSource(source.url) } }
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .tint(SpotTheme.settingsSelection)
        .safeAreaInset(edge: .bottom) { addSource }
    }

    private func leavePage(at place: StorePlace) {
        guard store.page != nil, store.place == place else { return }
        store.choose(place)
    }

    private var mine: some View {
        PageSidebarRow(title: "My spots") {
            SettingsTile(symbol: "house.fill", color: SpotTheme.storeMine, side: SpotTokens.settingsSectionTile)
        } trailing: {
            if drag.isOverTarget {
                Text("Drop to install")
                    .font(SpotType.settingsLine)
            }
        }
        .listRowBackground(drag.isOverTarget ? SpotTheme.settingsSelection.opacity(SpotTheme.storeDropFill) : nil)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(StoreDrag.space)) }, action: { drag.take(target: $0) })
    }

    private func sourceRow(_ source: StoreSource) -> some View {
        let isMissing = store.missing.contains(source.url.path)
        return PageSidebarRow(title: source.name) {
            SettingsTile(symbol: isMissing ? "questionmark.folder.fill" : source.symbol, color: SpotTheme.storeSource(source), side: SpotTokens.settingsSectionTile)
        } trailing: {
            if isMissing {
                Text("Not Found")
                    .font(SpotType.settingsLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var addSource: some View {
        Button {
            isAdding = true
        } label: {
            Label("Add Store…", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .padding(SpotTokens.settingsAccountInset)
        .sheet(isPresented: $isAdding) { StoreAddSheet(store: store, isShown: $isAdding) }
    }
}
