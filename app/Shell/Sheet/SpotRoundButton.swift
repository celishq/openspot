import OpenspotCore
import SwiftUI

struct SpotRoundButton: View {
    enum Look {
        case plain, floating, strong, bare
    }

    let symbol: String
    let label: String
    var act: ScriptCall?
    var size: CGFloat = SpotTokens.glyph
    var look = Look.plain
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let act {
                    SpotWorkMark(call: act, side: size, stops: true)
                } else {
                    Image(systemName: symbol)
                        .font(SpotType.roundSymbol(side: size))
                        .modifier(SpotInk())
                        .frame(width: size, height: size)
                }
            }
                .spotFill(isActive: act != nil || look == .strong, otherwise: fill, in: Circle())
                .background { if look == .floating { SpotFloatGlass(shape: Circle()) } }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(act == nil ? label : "Stop")
    }

    private var fill: Color {
        switch look {
        case .plain, .floating: SpotTheme.ink.opacity(SpotTheme.control)
        case .strong, .bare: .clear
        }
    }
}
