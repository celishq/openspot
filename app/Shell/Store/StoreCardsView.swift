import OpenspotCore
import SwiftUI

struct StoreCardsView: View {
    let store: Store

    private var source: StoreSource? {
        store.place.source
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.wordsGap) {
                Text(source?.name ?? "My spots")
                    .font(SpotType.title)
                Spacer(minLength: 0)
                StoreSearchField(store: store)
                    .frame(width: SpotTokens.storeSearchWidth)
            }
            if let source, store.missing.contains(source.url.path) {
                missing(source)
            } else if store.cards.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: SpotTokens.storeTileSize.width), spacing: SpotTokens.storeTileGap)], spacing: SpotTokens.storeTileGap) {
                        ForEach(store.cards) { card in
                            StoreTile(card: card, isFromSource: source != nil)
                                .onTapGesture { Task { await store.open(card.id) } }
                        }
                    }
                    .padding(.bottom, SpotTokens.storeInset)
                }
            }
        }
        .padding([.horizontal, .top], SpotTokens.storeInset)
    }

    private var empty: some View {
        VStack(spacing: SpotTokens.rowGap) {
            Text(store.query.isEmpty ? "No spots here yet." : "No spot here matches “\(store.query)”.")
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
            if !store.query.isEmpty {
                Button("Clear Search") { store.search("") }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func missing(_ source: StoreSource) -> some View {
        VStack(spacing: SpotTokens.rowGap) {
            Text("Folder Not Found")
                .font(SpotType.strong)
            Text("Openspot cannot find \(source.url.path). Locate the folder, or remove the source. The spots you got from it stay.")
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                .multilineTextAlignment(.center)
            HStack(spacing: SpotTokens.wordsGap) {
                Button("Remove") { Task { await store.removeSource(source.url) } }
                Button("Locate…") {
                    Task {
                        guard let folder = await SpotFolderPick.pick() else { return }
                        await store.addSource(folder)
                        await store.removeSource(source.url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: SpotTokens.storeAskWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
