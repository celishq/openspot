import OpenspotCore
import SwiftUI

struct SettingsAttachmentPicture: View {
    let chip: AttachmentChip

    var body: some View {
        let shape = SpotRoundShape(SurfaceEdge(card: .strip))
        HStack(spacing: SpotTokens.fieldTextGap) {
            SpotFieldPrompt.glyph
            SpotFieldPrompt(word: SearchPrompt.grid)
            Spacer(minLength: SpotTokens.settingsTrailingGap)
            SpotAttachmentCard(chip: chip, showsBadge: false, isQuiet: false)
        }
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: SpotTokens.layout.fieldHeight)
        .background { shape.fill(SpotTheme.highlight.opacity(SpotTheme.fill)) }
        .padding(.vertical, SpotTokens.settingsRowGap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The panel's field, with this attachment on its right")
    }
}
