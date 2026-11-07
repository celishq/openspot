import AppKit
import SwiftUI

/// One set of the panel's colours. A new theme is one more value of this type, chosen in `palette(for:)`. The static
/// colours follow the appearance of the view that draws them, and masks use plain black, which is not a colour here.
struct SpotTheme {
    /// Text and marks on a surface, and at less strength the fills on that surface.
    let ink: NSColor
    /// The fill of a turned-on card or a strong button.
    let solid: NSColor
    let onSolid: NSColor
    /// A glyph on the solid fill.
    let glyphOnSolid: NSColor
    /// The shade of a surface over its blur.
    let glass: NSColor
    /// The shade of a menu, which lies over the panel's own rows.
    let menuGlass: NSColor
    /// The shade around the panel, at its full strength.
    let tint: NSColor
    let keycap: NSColor
    /// The fill of a control that floats over a scrolling list.
    let float: NSColor
    /// The fill of a sandbox window or a rendered picture.
    let window: NSColor
    /// The fill of a preview card in the sandbox.
    let preview: NSColor
    let confirm: NSColor
    let onConfirm: NSColor
    /// The thin line down the sides of a surface's rim.
    let rimSides: NSColor
    /// The light or shade at the top and bottom of a surface's rim.
    let rimEnds: NSColor
    /// Whether the rim's ends add light to what lies behind them.
    let rimAddsLight: Bool
    /// The strength of the rim's side line at its top, at its middle and at its foot.
    let rimSideStrengths: [CGFloat]
    /// What lies under a surface to cast its shadow, and that shadow.
    let shadowBase: NSColor
    let shadow: NSColor
    /// The radius of the blur behind a surface.
    let blur: CGFloat
    /// The radius of the blur around the panel.
    let backdropBlur: CGFloat
    /// The strengths of ink as a fill: a row or a field, a selected one, a glyph's disc and a chip.
    let fillStrength: Double
    let selectedStrength: Double
    let discStrength: Double
    let chipStrength: Double
    let controlStrength: Double
    let trackStrength: Double
    let secondaryStrength: Double

    static let dark = SpotTheme(
        ink: .white,
        solid: .white,
        onSolid: .black,
        glyphOnSolid: .controlAccentColor,
        glass: .black.withAlphaComponent(0.3),
        menuGlass: .black.withAlphaComponent(0.3),
        tint: .black.withAlphaComponent(0.08),
        keycap: NSColor(white: 0.2, alpha: 1),
        float: NSColor(white: 0.34, alpha: 0.72),
        window: NSColor(white: 0.16, alpha: 1),
        preview: NSColor(white: 0.3, alpha: 1),
        confirm: NSColor(red: 0.78, green: 0.16, blue: 0.14, alpha: 1),
        onConfirm: .white,
        rimSides: .black,
        rimEnds: .white,
        rimAddsLight: true,
        rimSideStrengths: [0, 0.3, 0.3, 0],
        shadowBase: .clear,
        shadow: .clear,
        blur: 16,
        backdropBlur: 2,
        fillStrength: 0.1,
        selectedStrength: 0.22,
        discStrength: 0.2,
        chipStrength: 0.25,
        controlStrength: 0.2,
        trackStrength: 0.2,
        secondaryStrength: 0.7
    )

    static let light = SpotTheme(
        ink: NSColor(white: 0.11, alpha: 1),
        solid: NSColor(white: 0.12, alpha: 1),
        onSolid: .white,
        glyphOnSolid: .white,
        glass: .white.withAlphaComponent(0.5),
        menuGlass: .white,
        tint: .black.withAlphaComponent(0.08),
        keycap: NSColor(white: 0.98, alpha: 1),
        float: NSColor(white: 0.96, alpha: 0.82),
        window: NSColor(white: 0.93, alpha: 1),
        preview: NSColor(white: 0.98, alpha: 1),
        confirm: NSColor(red: 0.78, green: 0.16, blue: 0.14, alpha: 1),
        onConfirm: .white,
        rimSides: .black,
        rimEnds: .white.withAlphaComponent(0.5),
        rimAddsLight: true,
        rimSideStrengths: [0, 0.3, 0.3, 0],
        shadowBase: .clear,
        shadow: .clear,
        blur: 16,
        backdropBlur: 2,
        fillStrength: 0.04,
        selectedStrength: 0.08,
        discStrength: 0,
        chipStrength: 0.08,
        controlStrength: 0.05,
        trackStrength: 0.08,
        secondaryStrength: 0.7
    )

    static func palette(for appearance: NSAppearance) -> SpotTheme {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    }

    static func palette(for scheme: ColorScheme) -> SpotTheme {
        scheme == .dark ? dark : light
    }

    /// The theme of the app's appearance now.
    private static var current: SpotTheme {
        palette(for: NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing())
    }

    static let titleOpacity = 1.0
    static var secondaryLight: Double { current.secondaryStrength }
    static var fill: Double { current.fillStrength }
    static var disc: Double { current.discStrength }
    static var chip: Double { current.chipStrength }
    static var selectedFill: Double { current.selectedStrength }
    static let dragFill = 0.4
    static var track: Double { current.trackStrength }
    static var control: Double { current.controlStrength }
    static var blur: CGFloat { current.blur }

    static let ink = color(\.ink)
    static let solid = color(\.solid)
    static let onSolid = color(\.onSolid)
    static let glyphOnSolid = color(\.glyphOnSolid)
    static let glass = color(\.glass)
    static let shadowBase = color(\.shadowBase)
    static let shadow = color(\.shadow)
    static let menuGlass = color(\.menuGlass)
    static let keycap = color(\.keycap)
    static let float = color(\.float)
    static let window = color(\.window)
    static let preview = color(\.preview)
    static let confirm = color(\.confirm)
    static let onConfirm = color(\.onConfirm)

    private static func color(_ part: KeyPath<SpotTheme, NSColor> & Sendable) -> Color {
        Color(nsColor: NSColor(name: nil) { palette(for: $0)[keyPath: part] })
    }
}
