import OpenspotCore
import SwiftUI

struct SpotCardArrow: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(SpotType.mark)
            .frame(width: SpotTokens.arrowWidth)
            .modifier(SpotInk())
    }

    func placed(isTall: Bool) -> some View {
        padding(.trailing, isTall ? SpotTokens.padding : SpotTokens.arrowRowInset)
            .padding(.top, isTall ? SpotTokens.padding : 0)
            .frame(height: isTall ? nil : SpotTokens.rowHeight)
    }
}
