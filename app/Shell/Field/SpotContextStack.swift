import OpenspotCore
import SwiftUI

struct SpotContextStack: View {
    let model: SpotsModel

    var body: some View {
        let context = model.context
        let count = context.places.count
        ZStack(alignment: .trailing) {
            ForEach(context.places, id: \.chip.source) { place in
                SpotContextCard(chip: place.chip, showsBadge: place.showsKind && (context.isSpread || place.depth == 0))
                    .equatable()
                    .overlay(alignment: .bottom) {
                        SpotContextDot(isOn: context.isOn && place.chip.source == context.selected)
                    }
                    .scaleEffect(Self.scale(of: place, in: context), anchor: .trailing)
                    .offset(x: Self.x(of: place, in: context, count: count))
                    .opacity(Self.opacity(of: place, in: context))
                    .zIndex(Self.layer(of: place, in: context))
                    .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.contextStack(count: ContextStack.pile), height: SpotTokens.contextCard, alignment: .trailing)
        .compositingGroup()
        .contentShape(Rectangle())
        .onTapGesture { model.pressContext() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.contextPreview.map { $0.text.isEmpty ? $0.caption : $0.text } ?? "Context")
        .accessibilityAddTraits(.isButton)
    }

    private static func x(of place: ContextStack.Place, in context: ContextStack, count: Int) -> CGFloat {
        let shown = min(count, ContextStack.pile)
        guard context.isSpread else { return -CGFloat(shown - 1 - min(place.depth, shown - 1)) * SpotTokens.contextStep }
        let pitch = SpotTokens.contextCard + SpotTokens.contextSpreadGap
        let slot = place.depth == 0 ? place.slot : 0
        return -CGFloat(context.rowCount - 1 - slot) * pitch + (place.depth == 0 ? 0 : SpotTokens.contextStep)
    }

    private static func scale(of place: ContextStack.Place, in context: ContextStack) -> CGFloat {
        1 - CGFloat(min(place.depth, context.isSpread ? 1 : ContextStack.pile - 1)) * SpotTokens.contextShrink
    }

    private static func opacity(of place: ContextStack.Place, in context: ContextStack) -> Double {
        guard context.isSpread else { return place.depth < ContextStack.pile ? 1 : MotionTokens.hiddenOpacity }
        return place.depth == 0 ? 1 : place.depth == 1 ? 1 - SpotTheme.contextCardFade : MotionTokens.hiddenOpacity
    }

    private static func layer(of place: ContextStack.Place, in context: ContextStack) -> Double {
        context.isSpread ? -Double(place.slot) - Double(place.depth * context.row) : -Double(place.depth)
    }
}

private struct SpotContextDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(SpotTheme.accent)
            .frame(width: SpotTokens.contextDot, height: SpotTokens.contextDot)
            .offset(y: SpotTokens.contextDot + SpotTokens.contextDotGap)
            .opacity(isOn ? 1 : MotionTokens.hiddenOpacity)
            .transaction { $0.animation = nil }
            .allowsHitTesting(false)
    }
}
