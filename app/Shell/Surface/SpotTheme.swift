import AppKit
import SwiftUI

struct SpotTheme {
    let ink: NSColor
    let solid: NSColor
    let onSolid: NSColor
    let glyphOnSolid: NSColor
    let glass: NSColor
    let isMaterialTinted: Bool
    let shade: NSColor
    let keycap: NSColor
    let window: NSColor
    let preview: NSColor
    let confirm: NSColor
    let onConfirm: NSColor
    let rimEnds: NSColor
    let fillStrength: Double
    let selectedStrength: Double
    let discStrength: Double
    let chipStrength: Double
    let controlStrength: Double
    let trackStrength: Double

    static let dark = SpotTheme(
        ink: .white,
        solid: .white,
        onSolid: .black,
        glyphOnSolid: .controlAccentColor,
        glass: .clear,
        isMaterialTinted: true,
        shade: .black.withAlphaComponent(0.2),
        keycap: NSColor(white: 0.2, alpha: 1),
        window: NSColor(white: 0.16, alpha: 1),
        preview: NSColor(white: 0.3, alpha: 1),
        confirm: NSColor(red: 0.78, green: 0.16, blue: 0.14, alpha: 1),
        onConfirm: .white,
        rimEnds: .white,
        fillStrength: 0.1,
        selectedStrength: 0.22,
        discStrength: 0.2,
        chipStrength: 0.25,
        controlStrength: 0.2,
        trackStrength: 0.2
    )

    static let light = SpotTheme(
        ink: NSColor(white: 0.11, alpha: 1),
        solid: NSColor(white: 0.12, alpha: 1),
        onSolid: .white,
        glyphOnSolid: .white,
        glass: .white.withAlphaComponent(0.5),
        isMaterialTinted: false,
        shade: .black.withAlphaComponent(0.08),
        keycap: NSColor(white: 0.98, alpha: 1),
        window: NSColor(white: 0.93, alpha: 1),
        preview: NSColor(white: 0.98, alpha: 1),
        confirm: NSColor(red: 0.78, green: 0.16, blue: 0.14, alpha: 1),
        onConfirm: .white,
        rimEnds: .white.withAlphaComponent(0.5),
        fillStrength: 0.08,
        selectedStrength: 0.12,
        discStrength: 0,
        chipStrength: 0.1,
        controlStrength: 0.09,
        trackStrength: 0.12
    )

    static func palette(for appearance: NSAppearance) -> SpotTheme {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    }

    static func palette(for scheme: ColorScheme) -> SpotTheme {
        scheme == .dark ? dark : light
    }

    @MainActor private static var current: SpotTheme {
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        if let chosen, chosen.appearance === appearance { return chosen.theme }
        let theme = palette(for: appearance)
        chosen = (appearance, theme)
        return theme
    }

    @MainActor private static var chosen: (appearance: NSAppearance, theme: SpotTheme)?

    static let blur: CGFloat = 24
    static let backdropBlur: CGFloat = 3
    static let rimSides = NSColor.black
    static let rimSideStrengths: [CGFloat] = [0, 0.3, 0.3, 0]
    static let accent = Color.accentColor
    static let secondaryLight = 0.7
    static let dragFill = 0.4
    static let liftShadow: CGFloat = 14
    static let liftShadowStrength = 0.25
    static let unfocusedCardStrength = 0.35
    @MainActor static var fill: Double { current.fillStrength }
    static let edgeStrengths = [1.0, 0.7, 0.45]
    @MainActor static var disc: Double { current.discStrength }
    @MainActor static var chip: Double { current.chipStrength }
    @MainActor static var selectedFill: Double { current.selectedStrength }
    @MainActor static var track: Double { current.trackStrength }
    @MainActor static var control: Double { current.controlStrength }

    static let ink = color(\.ink)
    static let solid = color(\.solid)
    static let onSolid = color(\.onSolid)
    static let glyphOnSolid = color(\.glyphOnSolid)
    static let glass = color(\.glass)
    static let keycap = color(\.keycap)
    static let window = color(\.window)
    static let preview = color(\.preview)
    static let confirm = color(\.confirm)
    static let onConfirm = color(\.onConfirm)

    private static func color(_ part: KeyPath<SpotTheme, NSColor> & Sendable) -> Color {
        Color(nsColor: NSColor(name: nil) { palette(for: $0)[keyPath: part] })
    }
}
