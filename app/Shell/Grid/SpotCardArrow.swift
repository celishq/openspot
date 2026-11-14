import OpenspotCore
import SwiftUI

struct SpotCardArrow: View {
    static let rowInset: CGFloat = SpotTokens.padding - 6
    static let width: CGFloat = 7

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .frame(width: Self.width)
            .modifier(SpotInk())
    }

    func placed(isTall: Bool) -> some View {
        padding(.trailing, isTall ? SpotTokens.padding : Self.rowInset)
            .padding(.top, isTall ? SpotTokens.padding : 0)
            .frame(height: isTall ? nil : SpotTokens.rowHeight)
    }
}
