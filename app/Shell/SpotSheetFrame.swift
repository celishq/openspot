import SwiftUI

/// Places the sheet in a frame of the panel, so that it can grow out of a card and collapse back into it.
struct SpotSheetFrame: ViewModifier {
    let rect: CGRect
    let radius: CGFloat
    let showsRing: Bool
    /// The arrow of the card, which stays at the moving edge of the frame as the sheet grows out of the card.
    var arrow: AnyView?

    func body(content: Content) -> some View {
        content
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .overlay(alignment: .topTrailing) { arrow }
            .clipped()
            .modifier(SpotGlass(radius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .modifier(SpotSelectionRing(
                isSelected: showsRing,
                shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
                motion: SpotMotion.sheetFade(isOpen: !showsRing, isLate: showsRing)
            ))
            .offset(x: rect.minX, y: rect.minY)
    }
}
