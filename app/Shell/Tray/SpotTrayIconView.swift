import OpenspotCore
import SwiftUI

/// The icon of the Openspot item, or for a moment the symbol of the command whose key a person pressed, or of the toast
/// that shows. The leaving icon shrinks and fades as the next one grows in.
struct SpotTrayIconView: View {
    let model: SpotsModel
    let image: NSImage
    let toast: Toast?

    private static let small = 0.5
    private static let leave = SpotMotion.fade(isShown: false)
    private static let arrive = SpotMotion.press

    var body: some View {
        ZStack {
            icon
                .id(symbol)
                .transition(.asymmetric(
                    insertion: .scale(scale: Self.small).combined(with: .opacity).animation(Self.arrive),
                    removal: .scale(scale: Self.small).combined(with: .opacity).animation(Self.leave)
                ))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbol: String? {
        model.flashSymbol ?? toast.flatMap { $0.isShown ? $0.symbol : nil }
    }

    @ViewBuilder
    private var icon: some View {
        if let symbol {
            Image(systemName: symbol).font(SpotType.tray)
        } else {
            Image(nsImage: image).renderingMode(.template)
        }
    }
}
