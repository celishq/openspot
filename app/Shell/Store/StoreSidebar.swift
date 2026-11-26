import AppKit
import OpenspotCore
import SwiftUI

struct StoreSidebar: View {
    let store: Store
    @State private var isOverMine = false

    var body: some View {
        List(selection: Binding(get: { store.place }, set: { if let place = $0 { store.choose(place) } })) {
            mine
                .tag(StorePlace.mine)
            Section("Sources") {
                ForEach(store.sources, id: \.self) { source in
                    sourceRow(source)
                        .tag(StorePlace.source(source))
                        .contextMenu {
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([source.url]) }
                            if source.canRemove {
                                Button("Remove Source") { Task { await store.removeSource(source.url) } }
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .tint(SpotTheme.settingsSelection)
        .safeAreaInset(edge: .bottom) { addSource }
    }

    private var mine: some View {
        HStack(spacing: SpotTokens.settingsGroupGap) {
            SettingsTile(symbol: "house.fill", color: SpotTheme.storeMine, side: SpotTokens.settingsSectionTile)
            Text("My spots")
            Spacer(minLength: 0)
            if isOverMine {
                Text("Drop to install")
                    .font(SpotType.settingsLine)
            }
        }
        .listRowBackground(isOverMine ? SpotTheme.settingsSelection.opacity(SpotTheme.storeDropFill) : nil)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            Task { await store.install(id) }
            return true
        } isTargeted: { isOverMine = $0 }
    }

    private func sourceRow(_ source: StoreSource) -> some View {
        let isMissing = store.missing.contains(source.url.path)
        return HStack(spacing: SpotTokens.settingsGroupGap) {
            SettingsTile(symbol: isMissing ? "questionmark.folder.fill" : source.symbol, color: SpotTheme.storeSource(source), side: SpotTokens.settingsSectionTile)
            Text(source.name)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isMissing {
                Text("Not Found")
                    .font(SpotType.settingsLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var addSource: some View {
        Button {
            Task {
                guard let folder = await SpotFolderPick.pick() else { return }
                await store.addSource(folder)
            }
        } label: {
            Label("Add Source…", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .padding(SpotTokens.settingsAccountInset)
    }
}
