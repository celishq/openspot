import AppKit
import OpenspotCore
import SwiftUI

struct SpotTheme {
    let ink: NSColor
    let solid: NSColor
    let onSolid: NSColor
    let glyphOnSolid: NSColor
    let glass: NSColor
    let glassTint: NSColor
    let cornerFill: NSColor
    let window: NSColor
    let preview: NSColor
    let confirm: NSColor
    let onConfirm: NSColor
    let backdropTint: NSColor
    let fillStrength: Double
    let selectedStrength: Double
    let discStrength: Double
    let chipStrength: Double
    let controlStrength: Double
    let trackStrength: Double

    init(_ look: Theme.Appearance) {
        ink = look.ink.nsColor
        solid = look.solid.nsColor
        onSolid = look.onSolid.nsColor
        glyphOnSolid = look.glyphOnSolid.nsColor
        glass = look.glass.nsColor
        glassTint = look.glassTint.nsColor
        cornerFill = look.cornerFill.nsColor
        window = look.window.nsColor
        preview = look.preview.nsColor
        confirm = look.confirm.nsColor
        onConfirm = look.onConfirm.nsColor
        backdropTint = look.backdropTint.nsColor
        fillStrength = look.fill
        selectedStrength = look.selected
        discStrength = look.disc
        chipStrength = look.chip
        controlStrength = look.control
        trackStrength = look.track
    }

    @MainActor static func palette(for appearance: NSAppearance) -> SpotTheme {
        isDark(appearance) ? loaded.dark : loaded.light
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    @MainActor static var loaded: SpotPalette { SpotLoadedTheme.shared.palette }

    @MainActor private static var current: SpotTheme {
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        if let chosen, chosen.appearance === appearance { return chosen.isDark ? loaded.dark : loaded.light }
        let isDark = isDark(appearance)
        chosen = (appearance, isDark)
        return isDark ? loaded.dark : loaded.light
    }

    @MainActor private static var chosen: (appearance: NSAppearance, isDark: Bool)?

    @MainActor static var pictureRim: Color { loaded.pictureRim }

    @MainActor static var glassVariant: Glass {
        switch loaded.glassVariant {
        case .clear: .clear
        case .regular: .regular
        }
    }

    @MainActor static func glassStrength(at fade: Double) -> Double {
        min(fade * loaded.glassFadeReach, 1)
    }
    @MainActor static var accent: Color { loaded.accent }
    @MainActor static var good: Color { loaded.good }
    @MainActor static var warn: Color { loaded.warn }
    @MainActor static var bad: Color { loaded.bad }
    @MainActor static var secondaryLight: Double { loaded.shared.secondary }
    @MainActor static var dragFill: Double { loaded.shared.dragFill }
    @MainActor static var hover: Double { loaded.shared.hover }
    @MainActor static var menuDim: Double { loaded.shared.menuDim }
    static let liftShadow: CGFloat = 14
    static let chosenRow = 0.1
    @MainActor static var liftShadowStrength: Double { loaded.shared.liftShadowStrength }
    @MainActor static var unfocusedCardStrength: Double { loaded.shared.unfocusedCard }
    @MainActor static var fill: Double { current.fillStrength }
    @MainActor static var edgeStrengths: [Double] { loaded.edgeStrengths }
    @MainActor static var disc: Double { current.discStrength }
    @MainActor static var chip: Double { current.chipStrength }
    @MainActor static var selectedFill: Double { current.selectedStrength }
    @MainActor static var track: Double { current.trackStrength }
    @MainActor static var control: Double { current.controlStrength }

    @MainActor static var ink: Color { loaded.ink }
    static let glassInk = HierarchicalShapeStyle.primary
    static let glassSecondary = HierarchicalShapeStyle.secondary
    @MainActor static var solid: Color { loaded.solid }
    @MainActor static var onSolid: Color { loaded.onSolid }
    @MainActor static var glyphOnSolid: Color { loaded.glyphOnSolid }
    @MainActor static var glass: Color { loaded.glass }
    @MainActor static var glassTint: Color { loaded.glassTint }
    @MainActor static var backdropTint: Color { loaded.backdropTint }
    @MainActor static var cornerFill: Color { loaded.cornerFill }
    @MainActor static var window: Color { loaded.window }
    @MainActor static var preview: Color { loaded.preview }
    @MainActor static var confirm: Color { loaded.confirm }
    @MainActor static var onConfirm: Color { loaded.onConfirm }
}
