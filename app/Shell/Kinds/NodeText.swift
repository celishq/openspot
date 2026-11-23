import OpenspotCore
import SwiftUI

struct NodeText: View {
    let title: String?
    let detail: String?
    let tone: MetricValue.Tone?
    let icon: Icon?
    @Environment(\.multilineTextAlignment) private var alignment

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpotTokens.partLineGap) {
            if let icon {
                NodeIcon(icon: icon, side: SpotTokens.partSymbolWidth)
                    .modifier(SpotSecondaryText())
            }
            VStack(alignment: lines, spacing: SpotType.lineGap) {
                if let title {
                    if detail == nil, let colour = SpotToneWords.colour(of: tone) {
                        Text(title).foregroundStyle(colour)
                    } else {
                        Text(title)
                    }
                }
                if let detail {
                    Group {
                        if let colour = SpotToneWords.colour(of: tone) {
                            Text(detail).foregroundStyle(colour)
                        } else {
                            Text(detail).modifier(SpotSecondaryText())
                        }
                    }
                    .font(SpotType.detail)
                }
            }
        }
    }

    private var lines: HorizontalAlignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}
