import OpenspotCore
import SwiftUI

struct SpotContextStack: View {
    let model: SpotsModel

    var body: some View {
        let context = model.context
        ZStack(alignment: .trailing) {
            ForEach(context.places, id: \.chip.source) { place in
                SpotContextCard(chip: place.chip, showsBadge: place.chip.showsKind && (context.isSpread || place.depth == 0))
                    .equatable()
                    .overlay(alignment: .bottom) {
                        SpotContextDot(isOn: context.isOn && place.chip.source == context.selected)
                    }
                    .scaleEffect(place.scale, anchor: .trailing)
                    .offset(x: place.x)
                    .opacity(place.opacity)
                    .zIndex(place.layer)
                    .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.contextStack(count: ContextStack.pile), height: SpotTokens.contextCard, alignment: .trailing)
        .compositingGroup()
        .contentShape(Rectangle())
        .onTapGesture { model.pressContext() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.fieldValue.preview.map { $0.text.isEmpty ? $0.caption : $0.text } ?? "Context")
        .accessibilityAddTraits(.isButton)
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
