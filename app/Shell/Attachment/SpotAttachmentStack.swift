import OpenspotCore
import SwiftUI

struct SpotAttachmentStack: View {
    let model: SpotsModel

    var body: some View {
        let attachments = model.attachments
        ZStack(alignment: .trailing) {
            ForEach(attachments.layout.places, id: \.chip.source) { place in
                SpotAttachmentCard(chip: place.chip, showsBadge: !place.isQuiet && place.chip.showsKind && (attachments.layout.isSpread || place.depth == 0), isQuiet: place.isQuiet)
                    .equatable()
                    .overlay(alignment: .bottom) {
                        SpotAttachmentDot(isOn: attachments.isOn && place.chip.source == attachments.selected)
                    }
                    .scaleEffect(place.scale, anchor: .trailing)
                    .offset(x: place.x)
                    .opacity(place.opacity)
                    .zIndex(place.layer)
                    .transition(.opacity)
            }
        }
        .frame(width: SpotTokens.attachmentStack(count: AttachmentStack.pile), height: SpotTokens.attachmentCard, alignment: .trailing)
        .compositingGroup()
        .opacity(model.isAttachmentHidden ? MotionTokens.hiddenOpacity : 1)
        .contentShape(Rectangle())
        .onTapGesture { model.pressAttachment() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.fieldValue.preview.map { $0.text.isEmpty ? $0.caption : $0.text } ?? "Attachments")
        .accessibilityAddTraits(.isButton)
    }
}

private struct SpotAttachmentDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(SpotTheme.accent)
            .frame(width: SpotTokens.attachmentDot, height: SpotTokens.attachmentDot)
            .offset(y: SpotTokens.attachmentDot + SpotTokens.attachmentDotGap)
            .opacity(isOn ? 1 : MotionTokens.hiddenOpacity)
            .transaction { $0.animation = nil }
            .allowsHitTesting(false)
    }
}
