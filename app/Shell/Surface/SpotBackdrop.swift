import OpenspotCore
import SwiftUI

struct SpotBackdrop: View {
    let model: SpotsModel
    let motion: SheetMotion
    @Environment(\.spotDrawsGlass) private var drawsGlass
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        if drawsGlass, SpotTokens.backdrop.reach == .tiles, !model.isArranging {
            BackdropShape(rect: model.backdrop, foot: model.panelFoot, motion: motion, rest: (model.backdrop, model.panelFoot), style: SpotTokens.backdrop.style)
                .modifier(PanelSpan(grid: model.grid))
                .modifier(SpotShownFade(isShown: isShown))
                .allowsHitTesting(false)
        }
    }
}

private struct BackdropShape: View, @preconcurrency Animatable {
    var rect: CGRect
    var foot: PanelFoot
    var motion: SheetMotion
    let rest: (rect: CGRect, foot: PanelFoot)
    let style: Theme.Backdrop.Style

    var animatableData: AnimatablePair<CGRect.AnimatableData, AnimatablePair<PanelFoot.AnimatableData, Double>> {
        get { AnimatablePair(rect.animatableData, AnimatablePair(foot.animatableData, motion.progress)) }
        set {
            rect.animatableData = newValue.first
            foot.animatableData = newValue.second.first
            motion.progress = newValue.second.second
        }
    }

    var body: some View {
        let isMoving = motion.progress != 0 && motion.progress != 1 || rect != rest.rect || foot != rest.foot
        var rect = rect
        rect.size.height = motion.place(of: foot)
        return ZStack(alignment: .topLeading) {
            switch style {
            case .blur:
                SpotBackdropBlur(radius: SpotTokens.backdrop.blur, fadingIn: rect, isMoving: isMoving)
            case .tint:
                SpotBackdropTint(color: SpotTheme.backdropTint.color, fadingIn: rect, isMoving: isMoving)
            case .veil:
                SpotBackdropBlur(radius: SpotTokens.backdrop.blur, fadingIn: rect, isMoving: isMoving)
                SpotBackdropTint(color: SpotTheme.backdropTint.color, fadingIn: rect, isMoving: isMoving)
            }
        }
    }
}
