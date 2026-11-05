import OpenspotCore
import SwiftUI

/// The picture of an item: the icon of its file, or else its symbol, or else nothing.
struct SpotItemIcon: View {
    let item: SpotItem
    let size: CGFloat

    var body: some View {
        if let file = item.file {
            SpotFileIconView(icon: FileIcon(path: file), size: size)
        } else if let symbol = item.symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
    }
}

/// A file's icon read from the store. Its place stays empty until the bitmap is ready.
private struct SpotFileIconView: View {
    let icon: FileIcon
    let size: CGFloat
    @State private var loaded: CGImage?

    var body: some View {
        Group {
            if let image = SpotIconStore.shared.cached(icon) ?? loaded {
                Image(decorative: image, scale: SpotIconStore.scale)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .task(id: icon) {
            loaded = await SpotIconStore.shared.image(icon)
        }
    }
}
