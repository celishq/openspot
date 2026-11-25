import OpenspotCore
import SwiftUI

struct StoreMarkView: View {
    let mark: StoreMark

    private var words: (symbol: String?, title: String) {
        switch mark {
        case .installed: (nil, "Installed")
        case .core: ("lock.fill", "Core")
        case .edited: (nil, "Edited")
        case .update: (nil, "Update")
        }
    }

    var body: some View {
        HStack(spacing: SpotTokens.storeMarkGap) {
            if let symbol = words.symbol { Image(systemName: symbol) }
            Text(words.title)
        }
        .font(SpotType.mark)
        .foregroundStyle(mark == .update ? SpotTheme.onAccent : SpotTheme.ink.opacity(SpotTheme.secondary))
        .padding(.horizontal, SpotTokens.storeMarkPadding)
        .padding(.vertical, SpotTokens.storeMarkGap)
        .background(mark == .update ? SpotTheme.accent : SpotTheme.ink.opacity(SpotTheme.hover), in: Capsule())
    }
}
