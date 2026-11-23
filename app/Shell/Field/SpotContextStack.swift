import OpenspotCore
import SwiftUI

struct SpotContextStack: View {
    let model: SpotsModel

    var body: some View {
        let context = model.context
        let stack = context.stack
        ZStack(alignment: .leading) {
            ForEach(Array(stack.enumerated()), id: \.element.source) { place, chip in
                SpotContextCard(
                    chip: chip,
                    isOn: context.isOn && place == 0
                )
                .scaleEffect(1 - CGFloat(place) * SpotTokens.contextShrink, anchor: .trailing)
                .offset(x: CGFloat(place) * SpotTokens.contextStep)
                .opacity(1 - Double(place) * SpotTheme.contextCardFade)
                .zIndex(Double(-place))
                .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.contextStack(count: stack.count), height: SpotTokens.contextCard, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { model.pressContext() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(context.selectedChip?.words.title ?? "Context")
        .accessibilityAddTraits(.isButton)
    }
}
