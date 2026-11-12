import AppKit
import SwiftUI

/// One set of the panel's colours. A new theme is one more value of this type, chosen in `palette(for:)`. The static
/// colours follow the appearance of the view that draws them, and masks use plain black, which is not a colour here.
/// Values that every theme shares are plain constants below the themes.
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
    /// Whether a surface's blur keeps the system material's own fill, tone and saturation under `glass`.
    let isMaterialTinted: Bool
    /// The shade around the panel, at its full strength.
    let shade: NSColor
    let keycap: NSColor
    /// The fill of a sandbox window or a rendered picture.
    let window: NSColor
    /// The fill of a preview card in the sandbox.
    let preview: NSColor
    let confirm: NSColor
    let onConfirm: NSColor
    /// The light added at the top and bottom of a surface's rim.
    let rimEnds: NSColor
    /// The tint of the store, and the fill of a row on it.
    let well: NSColor
    let raised: NSColor
    /// The strengths of ink as a fill: a row or a field, a selected one, a glyph's disc and a chip.
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
        well: .black.withAlphaComponent(0.18),
        raised: .white.withAlphaComponent(0.08),
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
        well: .black.withAlphaComponent(0.05),
        raised: .white.withAlphaComponent(0.55),
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

    /// The theme of the app's appearance now, chosen once for each appearance.
    @MainActor private static var current: SpotTheme {
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        if let chosen, chosen.appearance === appearance { return chosen.theme }
        let theme = palette(for: appearance)
        chosen = (appearance, theme)
        return theme
    }

    @MainActor private static var chosen: (appearance: NSAppearance, theme: SpotTheme)?

    /// The radius of the blur behind a surface, and of the blur around the panel.
    static let blur: CGFloat = 24
    static let backdropBlur: CGFloat = 3
    /// The thin dark line down the sides of a surface's rim, at its top, its middle and its foot.
    static let rimSides = NSColor.black
    static let rimSideStrengths: [CGFloat] = [0, 0.3, 0.3, 0]
    /// The mark of the selected card, row or item, and of a drop.
    static let accent = Color.accentColor
    static let secondaryLight = 0.7
    static let dragFill = 0.4
    /// The shadow under a card that the person lifts in Edit Spots: its blur radius and its strength.
    static let liftShadow: CGFloat = 14
    static let liftShadowStrength = 0.25
    /// How strongly the veil of an open actions menu fades the content around its item.
    static let veil = 0.6
    @MainActor static var fill: Double { current.fillStrength }
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
    static let well = color(\.well)
    static let raised = color(\.raised)

    private static func color(_ part: KeyPath<SpotTheme, NSColor> & Sendable) -> Color {
        Color(nsColor: NSColor(name: nil) { palette(for: $0)[keyPath: part] })
    }
}
