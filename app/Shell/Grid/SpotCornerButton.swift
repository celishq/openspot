import OpenspotCore
import SwiftUI

struct SpotCornerButton: View {
    enum Corner {
        case leading, trailing
    }

    let symbol: String
    let label: String
    let corner: Corner
    let size: SpotSize
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
