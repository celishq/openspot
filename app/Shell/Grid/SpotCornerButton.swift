import OpenspotCore
import SwiftUI

/// A round button on a top corner of a card, on the rim of its round corner, such as the minus that turns a spot off in
/// Edit Spots.
struct SpotCornerButton: View {
    enum Corner {
        case leading, trailing
    }

    let symbol: String
    let label: String
    let corner: Corner
    let size: SpotSize
    /// Takes whether the pointer lies over the button. A button with it shows the panel's tip, and no tip of the system.
    var onHover: ((Bool) -> Void)?
    let action: () -> Void

    var body: some View {
        let inset = SpotTokens.corner(for: size) * SpotTokens.rimPoint - SpotTokens.keycap / 2
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SpotTheme.ink)
                .frame(width: SpotTokens.keycap, height: SpotTokens.keycap)
                .background(SpotTheme.keycap, in: Circle())
                .overlay(Circle().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(onHover == nil ? label : "")
        .accessibilityLabel(label)
        .onHover { onHover?($0) }
        .offset(x: corner == .leading ? inset : -inset, y: inset)
    }
}
