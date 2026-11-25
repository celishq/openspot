import OpenspotCore
import SwiftUI

struct NodeIcon: View {
    let icon: Icon?
    let side: CGFloat
    var pulses = false

    var body: some View {
        switch icon {
        case .symbol(let name):
            if pulses { SpotBreathingSymbol(name: name) } else { Image(systemName: name) }
        case .glyph(let text): Text(text)
        case .file(let path): SpotItemIcon(icon: FileIcon(path: path), glyph: nil, symbol: nil, size: side)
        case .image(let path): SpotItemIcon(icon: .image(path), glyph: nil, symbol: nil, size: side)
        case nil: EmptyView()
        }
    }
}
