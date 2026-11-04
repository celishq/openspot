import SwiftUI

/// Places the sheet in a frame of the panel, so that it can grow out of a card and collapse back into it.
struct SpotSheetFrame: ViewModifier {
    let rect: CGRect
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .clipped()
            .modifier(SpotGlass(radius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .offset(x: rect.minX, y: rect.minY)
    }
}
