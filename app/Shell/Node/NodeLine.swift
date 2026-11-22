import OpenspotCore
import SwiftUI

struct NodeLine<Trailing: View>: View {
    let part: SpotPart
    let size: CGSize
    var call: ScriptCall?
    var keepsIconColumn = false
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: size.width < SpotTokens.narrowCell ? SpotTokens.narrowGap : SpotTokens.partLineGap) {
            if !hasRoundMark, let call {
                SpotWorkMark(call: call, side: SpotTokens.workMark, stops: part.isPressable)
            } else if let icon = part.icon {
                NodeIcon(icon: icon, side: SpotTokens.partSymbolWidth)
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.partSymbolWidth)
            }
            else if keepsIconColumn {
                Color.clear.frame(width: SpotTokens.partSymbolWidth, height: 0)
            }
            if let title = part.title {
                Text(title)
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if part.title != nil || part.detail != nil {
                Spacer(minLength: 0)
            }
            if let detail = part.detail {
                Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
                    .layoutPriority(2)
            }
            trailing
        }
        .modifier(SpotColorBar(color: part.color))
    }

    private var hasRoundMark: Bool {
        if case .round = part.press { return true }
        return false
    }
}
