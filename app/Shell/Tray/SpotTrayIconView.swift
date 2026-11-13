import OpenspotCore
import SwiftUI

/// The icon of the Openspot item, or for a moment the symbol of the command whose key a person pressed. The leaving icon
/// shrinks and fades as the next one grows in.
struct SpotTrayIconView: View {
    let model: SpotsModel
    let image: NSImage

    private static let small = 0.5
    private static let leave = SpotMotion.fade(isShown: false)
    private static let arrive = SpotMotion.press

    var body: some View {
        ZStack {
            icon
                .id(model.flashSymbol)
                .transition(.asymmetric(
                    insertion: .scale(scale: Self.small).combined(with: .opacity).animation(Self.arrive),
                    removal: .scale(scale: Self.small).combined(with: .opacity).animation(Self.leave)
                ))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var icon: some View {
        if let symbol = model.flashSymbol {
            Image(systemName: symbol).font(SpotType.tray)
        } else {
            Image(nsImage: image).renderingMode(.template)
        }
    }
}
