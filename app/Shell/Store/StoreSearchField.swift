import OpenspotCore
import SwiftUI

struct StoreSearchField: View {
    let store: Store

    var body: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
            TextField("Search", text: Binding(get: { store.query }, set: { store.search($0) }))
                .textFieldStyle(.plain)
                .onExitCommand { store.search("") }
        }
        .font(SpotType.body)
        .padding(.horizontal, SpotTokens.windowRowPadding)
        .frame(height: SpotTokens.storeRowHeight)
        .background(SpotTheme.ink.opacity(SpotTheme.hover), in: SpotRoundShape(radius: SpotTokens.storeRowRadius))
    }
}
