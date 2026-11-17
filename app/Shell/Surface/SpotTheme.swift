import AppKit
import OpenspotCore
import SwiftUI

enum SpotTheme {
    @MainActor static func palette(for appearance: NSAppearance) -> Theme.Appearance {
        isDark(appearance) ? loaded.dark : loaded.light
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
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
    @MainActor static var accent: Color { loaded.accent }
    @MainActor static var good: Color { loaded.good }
    @MainActor static var warn: Color { loaded.warn }
    @MainActor static var bad: Color { loaded.bad }
    @MainActor static var secondaryLight: Double { current.secondary }
    static let glassFadeReach = 3.0
    static let dragFill = 0.4
    static let hover = 0.08
    static let menuDim = 0.4
    static let liftShadow: CGFloat = 14
    static let chosenRow = 0.1
    static let liftShadowStrength = 0.25
    static let unfocusedCardStrength = 0.35
    @MainActor static var fill: Double { current.fill }
    static let edgeStrengths = [1, 0.7, 0.45]
    @MainActor static var disc: Double { current.disc }
    @MainActor static var chip: Double { current.chip }
    @MainActor static var selectedFill: Double { current.selected }
    @MainActor static var track: Double { current.track }
    @MainActor static var control: Double { current.control }

    @MainActor static var ink: Color { loaded.ink }
    @MainActor static var glassInk: AnyShapeStyle { loaded.glassInk }
    @MainActor static var glassSecondary: AnyShapeStyle { loaded.glassSecondary }
    @MainActor static var solid: Color { loaded.solid }
    @MainActor static var onSolid: Color { loaded.onSolid }
    @MainActor static var glyphOnSolid: Color { loaded.glyphOnSolid }
    @MainActor static var glass: Color { loaded.glass }
    @MainActor static var glassTint: Color { loaded.glassTint }
    @MainActor static var backdropTint: Color { loaded.backdropTint }
    @MainActor static var highlight: Color { loaded.highlight }
    @MainActor static var cornerFill: Color { loaded.cornerFill }
    @MainActor static var window: Color { loaded.window }
    @MainActor static var confirm: Color { loaded.confirm }
    @MainActor static var onConfirm: Color { loaded.onConfirm }
}
