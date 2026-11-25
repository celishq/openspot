import AppKit
import OpenspotCore
import SwiftUI

struct StoreSidebar: View {
    let store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.storeRowGap) {
            StoreSidebarRow(store: store, place: .mine, symbol: "house", title: "My spots", isMissing: false)
            Text("Sources")
                .font(SpotType.small)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                .padding(.horizontal, SpotTokens.windowRowPadding)
                .padding(.top, SpotTokens.storeHeadingGap)
            ForEach(store.sources, id: \.self) { source in
                StoreSidebarRow(
                    store: store, place: .source(source), symbol: source.symbol, title: source.name,
                    isMissing: store.missing.contains(source.url.path)
                )
                .contextMenu {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([source.url]) }
                    if source.canRemove {
                        Button("Remove Source") { Task { await store.removeSource(source.url) } }
                    }
                }
            }
            Button {
                Task {
                    guard let folder = await SpotFolderPick.pick() else { return }
                    await store.addSource(folder)
                }
            } label: {
                Label("Add Source…", systemImage: "plus")
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                    .frame(maxWidth: .infinity, minHeight: SpotTokens.storeRowHeight, alignment: .leading)
                    .padding(.horizontal, SpotTokens.windowRowPadding)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(SpotTokens.storeInset)
    }
}
