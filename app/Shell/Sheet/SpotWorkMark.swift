import OpenspotCore
import SwiftUI

struct SpotWorkMark: View {
    let call: ScriptCall?
    var side = SpotTokens.glyphSize
    var stops = false
    @Environment(\.spotIsOnSolid) private var isOnSolid
    @Environment(\.colorScheme) private var scheme

    private var isLarge: Bool {
        side >= SpotTokens.glyphSize
    }

    private var colour: Color {
        isOnSolid ? SpotTheme.glyphOnSolid : SpotTheme.ink
    }

    var body: some View {
        ZStack {
            if let fill = call?.fill {
                SpotRing(
                    fill: fill,
                    line: isLarge ? SpotTokens.workThickLine : SpotTokens.workThinLine,
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
                RoundedRectangle(cornerRadius: side * SpotTokens.workSquareCorner)
                    .fill(colour)
                    .frame(width: side * SpotTokens.workSquareShare, height: side * SpotTokens.workSquareShare)
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement()
        .accessibilityLabel(stops ? "Stop" : "Running")
    }
}
