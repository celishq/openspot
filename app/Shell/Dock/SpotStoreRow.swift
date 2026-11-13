import OpenspotCore
import SwiftUI

/// A spot in the store as a card of the panel's grid, four columns wide, raised on the store with the card's rim: its picture, its
/// name, the one fact that matters under it, and the button of its next step with the arrow of its menu. The store's rows
/// take the pointer for every row, so that a row draws and tracks nothing of its own.
struct SpotStoreRow: View, Equatable {
    let item: SpotDock.Item

    var body: some View {
        let bounds = CGRect(x: 0, y: 0, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
        let radius = SpotTokens.corner(for: SpotSize(columns: 4, rows: 1))
        let step = SpotDock.stepRect(in: bounds)
        HStack(spacing: SpotTokens.padding - 5) {
            SpotItemIcon(icon: item.spot.icon, glyph: item.spot.glyph, symbol: item.spot.symbol, size: SpotTokens.glyphSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.spot.name)
                    .font(SpotType.title)
                    .foregroundStyle(SpotTheme.ink)
                if let fact {
                    Text(fact)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            StepButton(title: item.step.title)
                .frame(width: step.width + SpotTokens.storeArrowWidth, height: step.height)
        }
        .padding(.horizontal, SpotTokens.padding)
        .frame(width: bounds.width, height: bounds.height)
        .background(SpotTheme.raised, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .modifier(SpotGlass(radius: radius, blursBehind: false, rimSize: bounds.size))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.spot.name)
    }

    /// The line under the name: whether the store has a spot of the person's own as it is, that a built-in spot comes with
    /// the app, or else the spot's description.
    private var fact: String? {
        switch (item.origin, item.publication) {
        case (.mine, .current): "Published"
        case (.mine, .changed): "Changes not published"
        case (.mine, nil): "Not published"
        case (.builtIn, _): "Comes with Openspot"
        default: item.spot.subtitle
        }
    }
}

/// The button at the end of a row, as the App Store's Get: bold words in the accent on a pale pill, with the next step on
/// its main part and the arrow of the menu after a thin line.
private struct StepButton: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(SpotTheme.accent.opacity(0.3))
                .frame(width: 1, height: SpotTokens.storeButtonHeight / 2)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .frame(width: SpotTokens.storeArrowWidth - 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(SpotTheme.accent)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: Capsule())
    }
}
