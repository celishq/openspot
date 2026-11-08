import OpenspotCore
import SwiftUI

/// The card of a view while it builds: the spot's name over a soft light that sweeps across the card, which says that
/// work runs. With reduced motion the light stays still.
struct SpotViewPlaceholder: View {
    let title: String
    let size: CGSize
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    private static let period = 1.6
    private static let band = 0.6

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(paused: reducesMotion)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
                LinearGradient(colors: [.clear, SpotTheme.accent.opacity(0.14), SpotTheme.ink.opacity(0.06), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: size.width * Self.band, height: size.height)
                    .offset(x: size.width * ((1 + Self.band) * (reducesMotion ? 0.5 : phase) - Self.band))
            }
            Text(title)
                .font(SpotType.title)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                .padding(SpotTokens.padding)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
