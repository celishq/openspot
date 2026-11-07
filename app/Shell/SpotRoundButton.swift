import OpenspotCore
import SwiftUI

/// The round button of a sheet, with one symbol, such as close or swap. A button that floats on other content has a
/// background of its own, so that nothing shows through it. While its call runs, it shows that work and says Stop.
struct SpotRoundButton: View {
    enum Look {
        case plain, floating, strong, bare
    }

    private static let fillOpacity = 0.2
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
                    SpotWorkMark(call: work, side: size, stops: true, isOnSolid: look == .strong)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: max(size * Self.symbolRatio, 10), weight: .semibold))
                        .foregroundStyle(look == .strong ? SpotTheme.onSolid : SpotTheme.ink)
                        .frame(width: size, height: size)
                }
            }
                .background(fill, in: Circle())
                .background(look == .floating ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.clear), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(work == nil ? label : "Stop")
    }

    private var fill: AnyShapeStyle {
        switch look {
        case .plain: AnyShapeStyle(SpotTheme.ink.opacity(Self.fillOpacity))
        case .floating: AnyShapeStyle(SpotTheme.float)
        case .strong: AnyShapeStyle(SpotTheme.solid)
        case .bare: AnyShapeStyle(Color.clear)
        }
    }
}
