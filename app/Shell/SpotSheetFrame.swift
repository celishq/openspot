import SwiftUI

/// Places the sheet in a frame of the panel, so that it can grow out of a card and collapse back into it.
struct SpotSheetFrame: ViewModifier {
    let rect: CGRect
    let radius: CGFloat
    let ringOpacity: Double
    /// The arrow of the card, which stays at the moving edge of the frame as the sheet grows out of the card.
    var arrow: AnyView?

    func body(content: Content) -> some View {
        content
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .overlay(alignment: .topTrailing) { arrow }
            .clipped()
            .modifier(SpotGlass(radius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 2).animation(SpotMotion.sheetFade(isOpen: ringOpacity == 0, isLate: ringOpacity > 0)) { $0.opacity(ringOpacity) })
            .offset(x: rect.minX, y: rect.minY)
    }
}
