import OpenspotCore
import SwiftUI

/// A spot in the store as a row as wide as the panel's grid: its picture, its name, the one fact that matters under it, and
/// the button of its next step with the arrow of its menu. The store's rows take the pointer for every row, so that a row
/// draws and tracks nothing of its own.
struct SpotStoreRow: View, Equatable {
    let item: SpotDock.Item

    var body: some View {
        let bounds = CGRect(x: 0, y: 0, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
        let step = SpotDock.stepRect(in: bounds)
        HStack(spacing: SpotTokens.padding - 5) {
            SpotItemIcon(icon: item.command.icon, glyph: item.command.glyph, symbol: item.command.symbol, size: SpotTokens.glyphSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.command.name)
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
            StepButton(title: item.step.title, isStrong: item.step == .add || item.step == .publish)
                .frame(width: step.width + SpotTokens.storeArrowWidth, height: step.height)
        }
        .padding(.horizontal, SpotTokens.padding)
        .frame(width: bounds.width, height: bounds.height)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: RoundedRectangle(cornerRadius: SpotTokens.corner(for: SpotSize(columns: 4, rows: 1)), style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.command.name)
    }

    /// The line under the name: whether the store has a spot of the person's own as it is, that a built-in spot comes with
    /// the app, or else the spot's description.
    private var fact: String? {
        switch (item.origin, item.publication) {
        case (.mine, .current): "Published"
        case (.mine, .changed): "Changes not published"
        case (.mine, nil): "Not published"
        case (.builtIn, _): "Comes with Openspot"
        default: item.command.subtitle
        }
    }
}

/// The button at the end of a row: the next step on its main part, and the arrow of the menu after a thin line. A step that
/// changes the spot, Add or Publish, is drawn solid.
private struct StepButton: View {
    let title: String
    let isStrong: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(ink.opacity(SpotTheme.secondaryLight * 0.4))
                .frame(width: 1, height: SpotTokens.storeButtonHeight / 2)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .frame(width: SpotTokens.storeArrowWidth - 1)
        }
        .font(SpotType.action)
        .foregroundStyle(ink)
        .background(isStrong ? SpotTheme.ink : SpotTheme.keycap, in: Capsule())
        .overlay { if !isStrong { Capsule().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)) } }
    }

    private var ink: Color {
        isStrong ? SpotTheme.onSolid : SpotTheme.ink
    }
}
