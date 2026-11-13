import OpenspotCore
import SwiftUI

/// The round button of a sheet, with one symbol, such as close or swap. A button that floats on other content has the
/// sheet's own glass under it, so that it looks like a button on the sheet and nothing sharp shows through it. While its call runs, it fills solid, shows that work and says Stop.
struct SpotRoundButton: View {
    enum Look {
        case plain, floating, strong, bare
    }

    private static let symbolRatio: CGFloat = 0.32

    let symbol: String
    let label: String
    var work: ScriptCall?
    var size: CGFloat = SpotTokens.glyphSize
    var look = Look.plain
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let work {
                    SpotWorkMark(call: work, side: size, stops: true)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: max(size * Self.symbolRatio, 10), weight: .semibold))
                        .modifier(SpotInk())
                        .frame(width: size, height: size)
                }
            }
                .spotFill(isActive: work != nil || look == .strong, otherwise: fill, in: Circle())
                .background { if look == .floating { SpotFloatGlass(shape: Circle()) } }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(work == nil ? label : "Stop")
    }

    /// The fill of a button that is not active.
    private var fill: Color {
        switch look {
        case .plain, .floating: SpotTheme.ink.opacity(SpotTheme.control)
        case .strong, .bare: .clear
        }
    }
}
