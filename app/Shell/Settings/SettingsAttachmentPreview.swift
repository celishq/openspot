import OpenspotCore
import SwiftUI

struct SettingsAttachmentPreview: View {
    let chip: AttachmentChip
    let isOn: Bool

    var body: some View {
        let frame = SpotRoundShape(radius: SpotTokens.settingsPreviewRadius)
        HStack(spacing: 0) {
            SpotFieldPrompt.glyph
            Spacer(minLength: 0)
            SpotAttachmentCard(chip: chip, showsBadge: false, isQuiet: false)
                .opacity(isOn ? 1 : MotionTokens.hiddenOpacity)
        }
        .padding(.horizontal, SpotTokens.attachmentReach)
        .frame(height: SpotTokens.layout.fieldHeight)
        .background { SpotRoundShape(SurfaceEdge(card: .strip)).fill(SpotTheme.highlight.opacity(SpotTheme.fill)) }
        .padding(.horizontal, SpotTokens.padding)
        .frame(width: SpotTokens.settingsPreviewCrop, height: SpotTokens.settingsPreviewCropHeight)
        .scaleEffect(SpotTokens.settingsPreviewScale)
        .frame(width: SpotTokens.settingsPreviewWidth, height: SpotTokens.settingsPreviewHeight)
        .clipShape(frame)
        .overlay(frame.strokeBorder(SpotTheme.attachmentRim, lineWidth: SpotTokens.attachmentBorder))
        .accessibilityHidden(true)
    }
}
