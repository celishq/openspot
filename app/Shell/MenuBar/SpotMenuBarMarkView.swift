import OpenspotCore
import SwiftUI

/// What one menu bar item draws. Marks take the colour of the menu bar, and a tone adds colour where it means something.
struct SpotMenuBarMarkView: View {
    let mark: MenuBarMark

    private static let gap: CGFloat = 5
    private static let countGap: CGFloat = 3
    private static let padding: CGFloat = 6
    private static let dot: CGFloat = 7
    private static let ring: CGFloat = 14
    private static let ringLine: CGFloat = 2.5
    private static let track = 0.25
    private static let bar: CGFloat = 2
    private static let barGap: CGFloat = 1
    private static let barsHeight: CGFloat = 14
    private static let oldBar = 0.55
    private static let staleLight = 0.5

    private var markColour: Color {
        mark.tone.map(SpotMetricView.colour) ?? .primary
    }

    var body: some View {
        HStack(spacing: Self.gap) {
            if let symbol = mark.symbol, !mark.isRing {
                Image(systemName: symbol).foregroundStyle(markColour)
            }
            content
        }
        .font(SpotType.menuBar)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .padding(.horizontal, Self.padding)
        .frame(maxHeight: .infinity)
        .opacity(mark.isStale ? Self.staleLight : 1)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var content: some View {
        switch mark.content {
        case .counts(let counts):
            ForEach(Array(counts.enumerated()), id: \.offset) { _, count in
                HStack(spacing: Self.countGap) {
                    if let tone = count.tone { dot(SpotMetricView.colour(tone)) }
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
        }
    }

    private func dot(_ colour: Color) -> some View {
        Circle().fill(colour).frame(width: Self.dot, height: Self.dot)
    }

    private func ring(fill: Double) -> some View {
        SpotRing(fill: fill, line: Self.ringLine, colour: markColour, track: .primary.opacity(Self.track))
            .frame(width: Self.ring, height: Self.ring)
    }

    private func bars(_ points: [Double]) -> some View {
        HStack(alignment: .bottom, spacing: Self.barGap) {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Capsule()
                    .fill(markColour.opacity(index == points.count - 1 ? 1 : Self.oldBar))
                    .frame(width: Self.bar, height: max(CGFloat(point) * Self.barsHeight, Self.bar))
            }
        }
        .frame(height: Self.barsHeight, alignment: .bottom)
    }
}

private extension MenuBarMark {
    var isRing: Bool {
        if case .ring = content { return true }
        return false
    }
}
