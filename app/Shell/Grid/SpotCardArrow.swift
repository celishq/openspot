import OpenspotCore
import SwiftUI

/// The arrow of a card that opens a sheet. A row card centres it at the round end, and a tall card puts it in the top corner.
struct SpotCardArrow: View {
    /// The gap from the arrow of a row card to the card's trailing edge.
    static let rowInset: CGFloat = SpotTokens.padding - 6
    static let width: CGFloat = 7

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .frame(width: Self.width)
            .modifier(SpotInk())
    }

    /// The arrow in the place it has on a card, for a layer as large as that card or larger.
    func placed(isTall: Bool) -> some View {
        padding(.trailing, isTall ? SpotTokens.padding : Self.rowInset)
            .padding(.top, isTall ? SpotTokens.padding : 0)
            .frame(height: isTall ? nil : SpotTokens.rowHeight)
    }
}
