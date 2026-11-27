import OpenspotCore
import SwiftUI

struct NodeIcon: View {
    let icon: Icon?
    let side: CGFloat
    var pulses = false
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotMoves) private var moves

    var body: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .symbolEffect(.breathe.pulse.byLayer, options: .repeating, isActive: pulses && isShown && moves)
        case .glyph(let text): Text(text)
        case .file(let path): SpotItemIcon(icon: FileIcon(path: path), glyph: nil, symbol: nil, size: side)
        case .image(let path): SpotItemIcon(icon: .image(path), glyph: nil, symbol: nil, size: side)
        case .color(let hex): SpotItemIcon(color: hex, size: side)
        case nil: EmptyView()
        }
    }
}
