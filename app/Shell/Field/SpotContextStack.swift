import OpenspotCore
import SwiftUI

struct SpotContextStack: View {
    let model: SpotsModel

    var body: some View {
        let context = model.context
        let spread = model.contextSpread
        ZStack(alignment: .trailing) {
            ForEach(spread.places, id: \.chip.source) { place in
                SpotContextCard(chip: place.chip, showsBadge: place.depth == 0 && place.showsKind)
                    .equatable()
                    .overlay {
                        SpotContextRing(isOn: spread.isSpread && place.chip.source == spread.selected && place.depth == 0)
                    }
                    .scaleEffect(Self.scale(of: place, in: spread), anchor: .trailing)
                    .offset(x: Self.x(of: place, in: spread))
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

    static func x(of place: ContextSpread.Place, in spread: ContextSpread) -> CGFloat {
        guard spread.isSpread else { return -CGFloat(place.depth) * SpotTokens.contextStep }
        let pitch = SpotTokens.contextCard + SpotTokens.contextSpreadGap
        return place.depth == 0 ? -CGFloat(place.slot) * pitch : -CGFloat(spread.rowCount - 1) * pitch - SpotTokens.contextStep
    }

    static func selectedX(in spread: ContextSpread) -> CGFloat? {
        spread.places.first { $0.chip.source == spread.selected }.map { x(of: $0, in: spread) }
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

private struct SpotContextRing: View {
    let isOn: Bool

    var body: some View {
        SpotRoundShape(radius: SpotTokens.contextCardRadius + SpotTokens.contextEdge + SpotTokens.contextRingGap)
            .strokeBorder(SpotTheme.accent, lineWidth: SpotTokens.thinRing)
            .padding(-SpotTokens.contextEdge - SpotTokens.contextRingGap)
            .opacity(isOn ? 1 : MotionTokens.hiddenOpacity)
            .transaction { $0.animation = nil }
            .allowsHitTesting(false)
    }
}
