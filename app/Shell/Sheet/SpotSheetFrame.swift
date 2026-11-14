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
    var step = SheetStep()
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotPanels) private var panels

    func body(content: Content) -> some View {
        let shape = SpotSurfaceShape(rect: rect, radius: radius)
        let clip = step.clip.map { SpotSurfaceShape(rect: $0, radius: SpotTokens.radius) } ?? shape
        let width = panels.frame.width
        ZStack(alignment: .topLeading) {
            SpotSurface(rect: rect, radius: radius, marks: step.marks, markRoom: sheetRect)
            ZStack(alignment: .topLeading) {
                content
                    .frame(width: sheetRect.width, height: sheetRect.height, alignment: .topLeading)
                    .offset(x: sheetRect.minX + shift.width, y: sheetRect.minY + shift.height)
                    .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
                    .animation(SpotMotion.fade(isShown: isShown), value: isShown)
                    .allowsHitTesting(isShown)
                if let field = step.field {
                    field
                }
                if let arrow {
                    arrow
                        .frame(width: arrowBox.width, height: arrowBox.height, alignment: .topTrailing)
                        .offset(x: rect.maxX - arrowBox.width, y: rect.minY)
                }
            }
            .frame(width: width, height: SpotTokens.panelHeight, alignment: .topLeading)
            .scaleEffect(step.showsContent ? 1 : MotionTokens.stepScale, anchor: UnitPoint(x: sheetRect.midX / width, y: sheetRect.midY / SpotTokens.panelHeight))
            .opacity(step.showsContent ? 1 : MotionTokens.hiddenOpacity)
            .clipShape(clip)
        }
        .frame(width: width, height: SpotTokens.panelHeight, alignment: .topLeading)
        .modifier(SpotLiveSelectionRing(isSelected: isSelected, shape: shape, progress: progress))
        .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale, anchor: UnitPoint(x: rect.midX / width, y: rect.midY / SpotTokens.panelHeight))
        .animation(SpotMotion.fade(isShown: isShown), value: isShown)
    }
}
