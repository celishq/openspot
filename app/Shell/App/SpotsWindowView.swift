import OpenspotCore
import SwiftUI

/// What the panel's window shows: the panel, and in Edit Spots the dock under it, which fades in and stays built outside
/// the window after, and the card that the person carries over both, and the tip over all of them. The window's frame
/// changes at once, so the places in it never animate; only the panel's glide in Edit Spots does.
struct SpotsWindowView: View {
    let model: SpotsModel
    let place: SpotsWindowPlace

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpotsView(model: model)
                .animation(nil) { $0.offset(x: place.panel.x + place.left, y: place.panel.y) }
                .offset(y: place.lift)
            if let size = place.dock?.size ?? place.storeSize {
                SpotDockView(model: model, size: size)
                    .environment(\.spotIsShown, place.dock == nil || model.isShown)
                    .allowsHitTesting(place.dock != nil)
                    .accessibilityHidden(place.dock == nil)
                    .frame(width: place.dock == nil ? 0 : size.width, height: place.dock == nil ? 0 : size.height, alignment: .topLeading)
                    .animation(nil) { $0.offset(x: place.dock?.minX ?? Self.parked, y: place.dock?.minY ?? Self.parked) }
                    .opacity(place.isOut ? 1 : 0.001)
            }
            SpotCarriedCard(model: model, panel: CGPoint(x: place.panel.x + place.left, y: place.panel.y))
                .environment(\.spotIsShown, model.isShown)
            SpotTipView(model: model, panel: CGPoint(x: place.panel.x + place.left, y: place.panel.y))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Where the store lies while Edit Spots is off: far outside the window, so that it draws nothing, and in a frame of no
    /// size, so that the window's content keeps the window's size.
    private static let parked: CGFloat = -10_000
}
