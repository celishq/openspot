import OpenspotCore
import SwiftUI

/// The small picture of the thing an item belongs to, which sits over the top-left corner of the item's picture. It shows nothing with no badge.
struct SpotItemBadge: View {
    let badge: Icon?
    let side: CGFloat

    var body: some View {
        if let badge {
            SpotItemIcon(icon: badge.image.map(FileIcon.image) ?? badge.file.map(FileIcon.init(path:)), glyph: badge.glyph, symbol: badge.symbol, size: side / 2)
                .offset(x: -side / 6, y: -side / 6)
        }
    }
}
