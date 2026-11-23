import OpenspotCore
import SwiftUI

struct SpotContextStack: View {
    let model: SpotsModel

    var body: some View {
        let context = model.context
        let spread = model.contextSpread
        ZStack(alignment: .trailing) {
            ForEach(spread.places, id: \.chip.source) { place in
                SpotContextCard(
                    chip: place.chip,
                    isOn: place.chip.source == spread.selected && place.depth == 0,
                    showsBadge: place.depth == 0
                )
                .equatable()
                .scaleEffect(Self.scale(of: place, in: spread), anchor: .leading)
                .offset(x: Self.x(of: place, in: spread))
                .opacity(Self.opacity(of: place, in: spread))
                .zIndex(Double(-place.depth))
                .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.contextStack(count: ContextChips.limit), height: SpotTokens.contextCard, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture { model.pressContext() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(context.selectedChip?.words.title ?? "Context")
        .accessibilityAddTraits(.isButton)
    }

    private static func x(of place: ContextSpread.Place, in spread: ContextSpread) -> CGFloat {
        let pitch = SpotTokens.contextCard + SpotTokens.contextSpreadGap
        guard spread.isSpread else { return -CGFloat(place.depth) * SpotTokens.contextStep }
        let rowLeft = -CGFloat(spread.rowCount - 1) * pitch
        return place.depth == 0 ? rowLeft + CGFloat(place.slot) * pitch : rowLeft - SpotTokens.contextStep
    }

    private static func scale(of place: ContextSpread.Place, in spread: ContextSpread) -> CGFloat {
        1 - CGFloat(spread.isSpread ? min(place.depth, 1) : place.depth) * SpotTokens.contextShrink
    }

    private static func opacity(of place: ContextSpread.Place, in spread: ContextSpread) -> Double {
        guard spread.isSpread else { return max(1 - Double(place.depth) * SpotTheme.contextCardFade, 0) }
        return place.depth == 0 ? 1 : place.depth == 1 ? 1 - SpotTheme.contextCardFade : 0
    }
}
