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
        let width = panels.frame.width
        ZStack(alignment: .topLeading) {
            SpotSurface(rect: rect, radius: radius, marks: step.marks, markRoom: step.room ?? sheetRect)
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
            .modifier(PageFit(rect: step.fit ?? sheetRect, natural: sheetRect, isFitting: step.fit != nil, width: width))
            .clipShape(shape)
            if let leaving = step.leaving {
                leaving.look
                    .frame(width: width, height: SpotTokens.panelHeight, alignment: .topLeading)
                    .modifier(PageFit(rect: leaving.rect, natural: leaving.from, isFitting: true, width: width))
                    .clipShape(SpotSurfaceShape(rect: leaving.rect, radius: SpotTokens.cardRadius))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: SpotTokens.panelHeight, alignment: .topLeading)
        .modifier(SpotLiveSelectionRing(isSelected: isSelected, shape: shape, progress: progress))
        .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale, anchor: UnitPoint(x: rect.midX / width, y: rect.midY / SpotTokens.panelHeight))
        .animation(SpotMotion.fade(isShown: isShown), value: isShown)
    }
}

private struct PageFit: ViewModifier, @preconcurrency Animatable {
    var rect: CGRect
    let natural: CGRect
    let isFitting: Bool
    let width: CGFloat

    var animatableData: CGRect.AnimatableData {
        get { rect.animatableData }
        set { rect.animatableData = newValue }
    }

    func body(content: Content) -> some View {
        let rect = isFitting || rect.width != natural.width ? rect : natural
        let scale = min(rect.height / max(natural.height, 1), 1)
        let width = min(rect.width / max(natural.width, 1), 1)
        let shown = min(max((width - MotionTokens.stepFadeWidth) / (1 - MotionTokens.stepFadeWidth), MotionTokens.hiddenOpacity), 1)
        content
            .scaleEffect(scale, anchor: UnitPoint(x: natural.midX / self.width, y: natural.minY / SpotTokens.panelHeight))
            .offset(x: rect.midX - natural.midX, y: rect.minY - natural.minY)
            .opacity(shown)
    }
}
