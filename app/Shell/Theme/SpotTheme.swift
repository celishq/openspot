import AppKit
import OpenspotCore
import SwiftUI

enum SpotTheme {
    @MainActor static func palette(for appearance: NSAppearance) -> Theme.Appearance {
        isDark(appearance) ? loaded.dark : loaded.light
    }

    private static let darkNames: Set<NSAppearance.Name> = [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]

    static func isDark(_ appearance: NSAppearance) -> Bool {
        darkNames.contains(appearance.name)
    }

    @MainActor static var loaded: SpotPalette { SpotLoadedTheme.shared.palette }

    @MainActor private static var current: Theme.Appearance {
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        if let chosen, chosen.appearance === appearance { return chosen.isDark ? loaded.dark : loaded.light }
        let isDark = isDark(appearance)
        chosen = (appearance, isDark)
        return isDark ? loaded.dark : loaded.light
    }

    @MainActor private static var chosen: (appearance: NSAppearance, isDark: Bool)?

    static let pictureRim = ThemeColor(text: "#FFFFFF40")!.color

    @MainActor static var glassVariant: Glass {
        switch loaded.glassVariant {
        case .clear: .clear
        case .regular: .regular
        }
    }

    @MainActor static func glassStrength(at fade: Double) -> Double {
        min(fade * glassFadeReach, 1)
    }
    @MainActor static var accent: SpotColor { loaded.accent }
    @MainActor static var good: SpotColor { loaded.good }
    @MainActor static var warn: SpotColor { loaded.warn }
    @MainActor static var bad: SpotColor { loaded.bad }
    @MainActor static var secondary: Double { current.secondary }
    static let glassFadeReach = 3.0
    static let dragFill = 0.4
    static let hover = 0.08
    @MainActor static var menuDim: Double { current.menuDim }
    static let liftShadow: CGFloat = 14
    static let chosenRow = 0.1
    static let liftShadowStrength = 0.25
    static let unfocusedCardStrength = 0.35
    static let attachmentQuietPicture = 0.45
    @MainActor static var attachmentQuietFill: SpotColor { highlight.opacity(fill) }
    @MainActor static var attachmentRim: SpotColor { highlight.opacity(selectedFill + fill) }
    @MainActor static var attachmentTileTop: SpotColor { loaded.attachmentTileTop }
    @MainActor static var attachmentTileBottom: SpotColor { loaded.attachmentTileBottom }
    @MainActor static var attachmentTileInk: SpotColor { loaded.attachmentTileInk }
    @MainActor static var attachmentFace: SpotColor { loaded.attachmentFace }
    static let attachmentNearShadow = color(dark: .black.withAlphaComponent(0.35), light: .black.withAlphaComponent(0.10))
    static let attachmentFarShadow = color(dark: .black.withAlphaComponent(0.35), light: .black.withAlphaComponent(0.10))
    @MainActor static var fill: Double { current.fill }
    static let edgeStrengths = [1, 0.7, 0.45]
    @MainActor static var disc: Double { current.disc }
    @MainActor static var chip: Double { current.chip }
    @MainActor static var selectedFill: Double { current.selected }
    @MainActor static var track: Double { current.track }
    @MainActor static var control: Double { current.control }

    @MainActor static var ink: SpotColor { loaded.ink }
    @MainActor static func ink(onSolid: Bool) -> SpotColor { loaded.ink(onSolid: onSolid) }
    @MainActor static var glassInk: AnyShapeStyle { loaded.glassInk }
    @MainActor static var glassSecondary: AnyShapeStyle { loaded.glassSecondary }
    @MainActor static var solid: SpotColor { loaded.solid }
    @MainActor static var onSolid: SpotColor { loaded.onSolid }
    @MainActor static var glyphOnSolid: SpotColor { loaded.glyphOnSolid }
    @MainActor static var glass: SpotColor { loaded.glass }
    @MainActor static var glassTint: SpotColor { loaded.glassTint }
    @MainActor static var backdropTint: SpotColor { loaded.backdropTint }
    @MainActor static var cardShadow: SpotColor { loaded.cardShadow }
    @MainActor static var highlight: SpotColor { loaded.highlight }
    @MainActor static var cornerFill: SpotColor { loaded.cornerFill }
    @MainActor static var window: SpotColor { loaded.window }
    @MainActor static var confirm: SpotColor { loaded.confirm }
    @MainActor static var onConfirm: SpotColor { loaded.onConfirm }
    static let onAccent = Color.white
    static let capGlow = 0.28
    static let capBlank = 0.55
    static let capFace = color(dark: .white.withAlphaComponent(0.08), light: .white.withAlphaComponent(0.6))
    static let capRim = color(dark: .white.withAlphaComponent(0.14), light: .black.withAlphaComponent(0.1))
    static let capEdge = color(dark: .black.withAlphaComponent(0.35), light: .black.withAlphaComponent(0.14))
    static let attachmentDivider = color(dark: .white.withAlphaComponent(0.08), light: .black.withAlphaComponent(0.07))
    static let well = color(dark: .black.withAlphaComponent(0.22), light: .black.withAlphaComponent(0.05))

    private static func color(dark: NSColor, light: NSColor) -> SpotColor {
        SpotPalette.color(dark, light)
    }
}
