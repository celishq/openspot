import OpenspotCore
import SwiftUI

/// Running work in one slot: a ring from its fill, or the system's spinner with no fill. A square inside says that a press
/// stops it. It takes the place of whatever the slot shows when no work runs.
struct SpotWorkMark: View {
    let call: ScriptCall
    var side = SpotTokens.glyphSize
    var stops = false
    var isOnSolid = false
    @Environment(\.colorScheme) private var scheme

    private static let thickLine: CGFloat = 4
    private static let thinLine: CGFloat = 2.5
    private static let squareRatio: CGFloat = 0.28
    private static let squareCorner: CGFloat = 0.06

    private var isLarge: Bool {
        side >= SpotTokens.glyphSize
    }

    private var colour: Color {
        isOnSolid ? SpotTheme.glyphOnSolid : SpotTheme.ink
    }

    var body: some View {
        ZStack {
            if let fill = call.fill {
                SpotRing(
                    fill: fill,
                    line: isLarge ? Self.thickLine : Self.thinLine,
                    colour: colour,
                    track: (isOnSolid ? SpotTheme.onSolid : SpotTheme.ink).opacity(SpotTheme.track)
                )
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(isLarge ? .regular : .small)
                    .environment(\.colorScheme, isOnSolid ? (scheme == .dark ? .light : .dark) : scheme)
            }
            if stops {
                RoundedRectangle(cornerRadius: side * Self.squareCorner)
                    .fill(colour)
                    .frame(width: side * Self.squareRatio, height: side * Self.squareRatio)
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement()
        .accessibilityLabel(stops ? "Stop" : "Running")
    }
}
