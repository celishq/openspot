import Observation
import OpenspotCore
import SwiftUI

@MainActor @Observable
final class SpotLoadedTheme {
    static let shared = SpotLoadedTheme()
    private static let viewThemeLimit = 32

    @ObservationIgnored private var painted = Theme.Look()
    @ObservationIgnored private var viewThemes: [ViewThemeKey: [String: Any]] = [:]
    private(set) var palette = SpotPalette(Theme.Look())
    private(set) var layout = 0

    func take(_ next: Theme) {
        paint(next.look)
        lay(next.layout)
    }

    func paint(_ next: Theme.Look) {
        guard next != painted else { return }
        painted = next
        viewThemes = [:]
        palette = SpotPalette(next)
    }

    func lay(_ next: Theme.Layout) {
        SpotTokens.take(next)
        SpotType.take(next.type)
        SpotBackdropEdge.draw()
        viewThemes = [:]
        layout += 1
    }

    func viewTheme(isDark: Bool, corner: CGFloat) -> [String: Any] {
        let palette = palette
        let name = ViewThemeKey(isDark: isDark, corner: corner)
        if let kept = viewThemes[name] { return kept }
        let values = ViewTheme(
            layout: SpotTokens.layout, look: isDark ? palette.dark : palette.light, corner: corner, colour: palette.color, face: SpotType.face
        ).values
        if viewThemes.count >= Self.viewThemeLimit { viewThemes = [:] }
        viewThemes[name] = values
        return values
    }
}

private struct ViewThemeKey: Hashable {
    let isDark: Bool
    let corner: CGFloat
}
