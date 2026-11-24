import OpenspotCore
import SwiftUI

struct SpotContextStack: View {
    let model: SpotsModel

    var body: some View {
        let context = model.context
        ZStack(alignment: .trailing) {
            SpotContextKey(isQuiet: context.layout.isQuiet, isShown: context.layout.showsKey)
                .zIndex(-Double(ContextStack.limit * ContextStack.limit))
            ForEach(context.layout.places, id: \.chip.source) { place in
                SpotContextCard(chip: place.chip, showsBadge: !place.isQuiet && place.chip.showsKind && (context.layout.isSpread || place.depth == 0), isQuiet: place.isQuiet)
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

private struct SpotContextKey: View {
    let isQuiet: Bool
    let isShown: Bool

    var body: some View {
        Text(verbatim: "⇥")
            .font(SpotType.detail)
            .modifier(SpotSecondaryText())
            .frame(width: SpotTokens.contextKeyWidth, height: SpotTokens.contextQuietIcon)
            .background(SpotRoundShape(radius: SpotTokens.contextQuietRadius).fill(SpotTheme.contextQuietFill))
            .offset(x: SpotTokens.contextKeyX + (isQuiet ? 0 : SpotTokens.contextKeySlide))
            .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
            .allowsHitTesting(false)
    }
}
