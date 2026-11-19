import OpenspotCore
import SwiftUI

struct MenuBarMarkItemView: View {
    let mark: MenuBarMark

    private var markColour: Color {
        SpotToneWords.colour(of: mark.tone) ?? .primary
    }

    var body: some View {
        HStack(spacing: SpotTokens.menuBarGap) {
            if let symbol = mark.symbol, !mark.isRing {
                Image(systemName: symbol).foregroundStyle(markColour)
            }
            content
        }
        .font(SpotType.menuBar)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .padding(.horizontal, SpotTokens.menuBarPadding)
        .frame(maxHeight: .infinity)
        .opacity(mark.isStale ? SpotTheme.stale : 1)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var content: some View {
        switch mark.content {
        case .counts(let counts):
            ForEach(Array(counts.enumerated()), id: \.offset) { _, count in
                HStack(spacing: SpotTokens.menuBarCountGap) {
                    if let colour = SpotToneWords.colour(of: count.tone) { dot(colour) }
                    Text("\(count.count)")
                }
            }
        case .text(let title):
            Text(title)
        case .ring(let fill, let title):
            ring(fill: fill)
            Text(title)
        case .bars(let points, let title):
            bars(points)
            Text(title)
        case .status(let title):
            dot(markColour)
            Text(title)
        case .icon:
            EmptyView()
        }
    }

    private func dot(_ colour: Color) -> some View {
        Circle().fill(colour).frame(width: SpotTokens.toneDot, height: SpotTokens.toneDot)
    }

    private func ring(fill: Double) -> some View {
        SpotRing(fill: fill, line: SpotTokens.menuBarRingLine, colour: markColour, track: .primary.opacity(SpotTheme.menuBarTrack))
            .frame(width: SpotTokens.menuBarRing, height: SpotTokens.menuBarRing)
    }

    private func bars(_ points: [Double?]) -> some View {
        HStack(alignment: .bottom, spacing: SpotTokens.menuBarBarGap) {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Capsule()
                    .fill(markColour.opacity(point == nil ? 0 : index == points.count - 1 ? 1 : SpotTheme.oldBar))
                    .frame(width: SpotTokens.menuBarBar, height: max(CGFloat(point ?? 0) * SpotTokens.menuBarBarsHeight, SpotTokens.menuBarBar))
            }
        }
        .frame(height: SpotTokens.menuBarBarsHeight, alignment: .bottom)
    }
}

private extension MenuBarMark {
    var isRing: Bool {
        if case .ring = content { return true }
        return false
    }
}
