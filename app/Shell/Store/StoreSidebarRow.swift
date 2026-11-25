import OpenspotCore
import SwiftUI

struct StoreSidebarRow: View {
    let store: Store
    let place: StorePlace
    let symbol: String
    let title: String
    let isMissing: Bool
    @State private var isHovered = false

    private var takesDrop: Bool {
        place == .mine
    }

    var body: some View {
        let isChosen = store.place == place
        HStack(spacing: SpotTokens.wordsGap) {
            Image(systemName: isMissing ? "questionmark.folder" : symbol)
                .font(SpotType.rowIcon)
                .frame(width: SpotTokens.storeRowIcon)
            Text(title)
                .font(SpotType.body)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isHovered {
                Text(takesDrop ? "Install" : "Read only")
                    .font(SpotType.small)
            } else if isMissing {
                Text("Not Found")
                    .font(SpotType.small)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
            }
        }
        .foregroundStyle(isHovered && takesDrop ? SpotTheme.onAccent : SpotTheme.ink)
        .padding(.horizontal, SpotTokens.windowRowPadding)
        .frame(height: SpotTokens.storeRowHeight)
        .background(fill(isChosen: isChosen), in: SpotRoundShape(radius: SpotTokens.storeRowRadius))
        .contentShape(SpotRoundShape(radius: SpotTokens.storeRowRadius))
        .onTapGesture { store.choose(place) }
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
        .dropDestination(for: String.self) { ids, _ in
            guard takesDrop, let id = ids.first else { return false }
            Task { await store.install(id) }
            return true
        } isTargeted: { isHovered = $0 }
    }

    private func fill(isChosen: Bool) -> Color {
        if isHovered { return takesDrop ? SpotTheme.accent : SpotTheme.ink.opacity(SpotTheme.hover) }
        return isChosen ? SpotTheme.ink.opacity(SpotTheme.chosenRow) : .clear
    }
}
