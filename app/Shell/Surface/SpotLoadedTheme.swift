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
        SpotTokens.take(next.layout)
        lay(next.layout)
    }

    func paint(_ next: Theme.Look) {
        guard next != painted else { return }
        painted = next
        viewThemes = [:]
        palette = SpotPalette(next)
    }

    func lay(_ next: Theme.Layout) {
        SpotType.take(next.type)
        SpotBackdropEdge.draw()
        viewThemes = [:]
        layout += 1
    }

    func viewTheme(isDark: Bool, corner: CGFloat) -> [String: Any] {
        let palette = palette
        let name = ViewThemeKey(isDark: isDark, corner: corner)
        if let kept = viewThemes[name] { return kept }
        let look = isDark ? palette.dark : palette.light
        var values: [String: Any] = ViewTheme(sizes: SpotTokens.sizes, motion: MotionTokens.motion, corner: corner).numbers
        values["ink"] = palette.ink
        values["solid"] = palette.solid
        values["onSolid"] = palette.onSolid
        values["accent"] = palette.accent
        values["good"] = palette.good
        values["warn"] = palette.warn
        values["bad"] = palette.bad
        values["secondary"] = CGFloat(palette.shared.secondary)
        values["fill"] = CGFloat(look.fillStrength)
        values["selected"] = CGFloat(look.selectedStrength)
        values["track"] = CGFloat(look.trackStrength)
        values["title"] = SpotType.title
        values["body"] = SpotType.body
        values["detail"] = SpotType.detail
        values["input"] = SpotType.input
        if viewThemes.count >= Self.viewThemeLimit { viewThemes = [:] }
        viewThemes[name] = values
        return values
    }
}

private struct ViewThemeKey: Hashable {
    let isDark: Bool
    let corner: CGFloat
}
