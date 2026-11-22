import OpenspotCore
import SwiftUI

struct NodeIcon: View {
    let icon: Icon?

    var body: some View {
        switch icon {
        case .symbol(let name): Image(systemName: name)
        case .glyph(let text): Text(text)
        case .file(let path): SpotItemIcon(icon: FileIcon(path: path), glyph: nil, symbol: nil, size: SpotTokens.listIconSize)
        case .image(let path): SpotItemIcon(icon: .image(path), glyph: nil, symbol: nil, size: SpotTokens.listIconSize)
        case nil: EmptyView()
        }
    }
}
