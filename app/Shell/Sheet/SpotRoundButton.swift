import OpenspotCore
import SwiftUI

struct SpotRoundButton: View {
    enum Look {
        case plain, strong, bare
    }

    let icon: Icon
    let label: String
    var act: ScriptCall?
    var size: CGFloat = SpotTokens.glyph
    var look = Look.plain
    let action: () -> Void

    private var side: CGFloat {
        look == .bare ? min(size, SpotTokens.slotButton) : size
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let act {
                    SpotWorkMark(call: act, side: side, stops: true)
                } else {
                    NodeIcon(icon: icon, side: side / 2)
                        .font(SpotType.roundSymbol(side: side))
                        .modifier(SpotInk())
                        .frame(width: side, height: side)
                }
            }
                .spotFill(isActive: act != nil || look == .strong, otherwise: fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(act == nil ? label : "Stop")
    }

    private var fill: Color {
        switch look {
        case .plain: SpotTheme.ink.opacity(SpotTheme.control)
        case .strong, .bare: .clear
        }
    }
}
