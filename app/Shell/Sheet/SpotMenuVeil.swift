import OpenspotCore
import SwiftUI

/// The veil that fades the content around the item of the open actions menu, with a hole in the shape of that item. Over a
/// sheet its top is square, as it starts under the sheet's field.
struct SpotMenuVeil: View {
    let area: CGRect
    let isSquareOnTop: Bool
    let item: CGRect
    let corner: CGFloat

    var body: some View {
        Path { path in
            let top = isSquareOnTop ? 0 : SpotTokens.radius
            path.addPath(UnevenRoundedRectangle(
                topLeadingRadius: top,
                bottomLeadingRadius: SpotTokens.radius,
                bottomTrailingRadius: SpotTokens.radius,
                topTrailingRadius: top,
                style: .continuous
            ).path(in: area))
            path.addRoundedRect(in: item, cornerSize: CGSize(width: corner, height: corner), style: .continuous)
        }
        .fill(SpotTheme.window.opacity(SpotTheme.veil), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }
}
