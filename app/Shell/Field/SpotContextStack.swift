import OpenspotCore
import SwiftUI

struct SpotContextStack: View {
    let model: SpotsModel

    var body: some View {
        let context = model.context
        let spread = model.contextSpread
        let count = spread.places.count
        ZStack(alignment: .trailing) {
            ForEach(spread.places, id: \.chip.source) { place in
                SpotContextCard(chip: place.chip, showsBadge: place.showsKind && (spread.isSpread || place.depth == 0))
                    .equatable()
                    .overlay(alignment: .bottom) {
                        SpotContextDot(isOn: context.isOn && place.chip.source == context.selected)
                    }
                    .scaleEffect(Self.scale(of: place, in: spread), anchor: .trailing)
                    .offset(x: Self.x(of: place, in: spread, count: count))
                    .opacity(Self.opacity(of: place, in: spread))
                    .zIndex(Self.layer(of: place, in: spread))
                    .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.contextStack(count: ContextChips.limit), height: SpotTokens.contextCard, alignment: .trailing)
        .compositingGroup()
        .contentShape(Rectangle())
        .onTapGesture { model.pressContext() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(context.selectedChip?.words.title ?? "Context")
        .accessibilityAddTraits(.isButton)
    }

    private static func x(of place: ContextSpread.Place, in spread: ContextSpread, count: Int) -> CGFloat {
        guard spread.isSpread else { return -CGFloat(count - 1 - place.depth) * SpotTokens.contextStep }
        let pitch = SpotTokens.contextCard + SpotTokens.contextSpreadGap
        let slot = place.depth == 0 ? place.slot : 0
        return -CGFloat(spread.rowCount - 1 - slot) * pitch + (place.depth == 0 ? 0 : SpotTokens.contextStep)
    }

    private static func scale(of place: ContextSpread.Place, in spread: ContextSpread) -> CGFloat {
        1 - CGFloat(spread.isSpread ? min(place.depth, 1) : place.depth) * SpotTokens.contextShrink
    }

    private static func opacity(of place: ContextSpread.Place, in spread: ContextSpread) -> Double {
        guard spread.isSpread else { return 1 }
        return place.depth == 0 ? 1 : place.depth == 1 ? 1 - SpotTheme.contextCardFade : MotionTokens.hiddenOpacity
    }

    private static func layer(of place: ContextSpread.Place, in spread: ContextSpread) -> Double {
        spread.isSpread ? -Double(place.slot) - Double(place.depth * ContextSpread.row) : -Double(place.depth)
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
