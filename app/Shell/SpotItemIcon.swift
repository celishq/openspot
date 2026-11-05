import AppKit
import OpenspotCore
import SwiftUI

/// The picture of an item: the icon of its file, or else its symbol, or else nothing.
struct SpotItemIcon: View {
    let item: SpotItem
    let size: CGFloat

    var body: some View {
        if let file = item.file {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file))
                .resizable()
                .frame(width: size, height: size)
        } else if let symbol = item.symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
    }
}
