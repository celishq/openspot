import OpenspotCore
import SwiftUI

struct SpotNativeIcon: View {
    let path: String
    let size: CGFloat
    @State private var loaded: CGImage?

    var body: some View {
        let pixels = Int((size * SpotTokens.pictureScale).rounded(.up))
        Group {
            if let image = SpotIconStore.shared.cachedNative(path, pixels: pixels) ?? loaded {
                Image(decorative: image, scale: SpotTokens.pictureScale)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .task(id: path) {
            loaded = await SpotIconStore.shared.native(path, pixels: pixels)
        }
    }
}
