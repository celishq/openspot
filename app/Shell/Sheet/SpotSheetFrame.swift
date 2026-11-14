import OpenspotCore
import SwiftUI

struct SpotSheetFrame: ViewModifier {
    let rect: CGRect
    let radius: CGFloat
    let sheetRect: CGRect
    let shift: CGSize
    let isSelected: () -> Bool
    let progress: Double
    var arrow: AnyView?
    var arrowBox: CGSize = .zero
    var glass = 1.0
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotPanels) private var panels

    func body(content: Content) -> some View {
        let shape = SpotSurfaceShape(rect: rect, radius: radius)
        ZStack(alignment: .topLeading) {
            SpotSurface(rect: rect, radius: radius, glass: glass)
            content
                .frame(width: sheetRect.width, height: sheetRect.height, alignment: .topLeading)
                .offset(x: sheetRect.minX + shift.width, y: sheetRect.minY + shift.height)
                .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
                .animation(SpotMotion.fade(isShown: isShown), value: isShown)
                .allowsHitTesting(isShown)
            if let arrow {
                arrow
                    .frame(width: arrowBox.width, height: arrowBox.height, alignment: .topTrailing)
                    .offset(x: rect.maxX - arrowBox.width, y: rect.minY)
            }
        }
        .frame(width: panels.frame.width, height: SpotTokens.panelHeight, alignment: .topLeading)
        .clipShape(shape)
        .modifier(SpotLiveSelectionRing(isSelected: isSelected, shape: shape, progress: progress))
        .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale, anchor: UnitPoint(x: rect.midX / panels.frame.width, y: rect.midY / SpotTokens.panelHeight))
        .animation(SpotMotion.fade(isShown: isShown), value: isShown)
    }
}
