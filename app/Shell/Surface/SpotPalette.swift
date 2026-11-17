import AppKit
import OpenspotCore
import SwiftUI

final class SpotPalette: Sendable {
    let dark: Theme.Appearance
    let light: Theme.Appearance
    let ink: Color
    let solid: Color
    let onSolid: Color
    let glyphOnSolid: Color
    let glass: Color
    let glassTint: Color
    let cornerFill: Color
    let window: Color
    let confirm: Color
    let onConfirm: Color
    let backdropTint: Color
    let highlight: Color
    let accent: Color
    let good: Color
    let warn: Color
    let bad: Color
    let glassInk: AnyShapeStyle
    let glassSecondary: AnyShapeStyle
    let glassVariant: Theme.Glass.Variant

    init(_ look: Theme.Look) {
        dark = look.dark
        light = look.light
        let color = { (part: KeyPath<Theme.Appearance, ThemeColor>) in Self.color(part, dark: look.dark, light: look.light) }
        ink = color(\.ink)
        solid = color(\.solid)
        onSolid = color(\.onSolid)
        glyphOnSolid = color(\.glyphOnSolid)
        glass = color(\.glass)
        glassTint = color(\.glassTint)
        cornerFill = color(\.cornerFill)
        window = color(\.window)
        confirm = color(\.confirm)
        onConfirm = color(\.onConfirm)
        backdropTint = color(\.backdropTint)
        highlight = color(\.highlight)
        accent = color(\.accent)
        good = color(\.good)
        warn = color(\.warn)
        bad = color(\.bad)
        let secondary = { (look: Theme.Appearance) in
            let ink = look.ink.nsColor
            return ink.withAlphaComponent(ink.alphaComponent * look.secondary)
        }
        glassInk = look.glass.takesInk ? AnyShapeStyle(ink) : AnyShapeStyle(HierarchicalShapeStyle.primary)
        glassSecondary = look.glass.takesInk ? AnyShapeStyle(Self.color(secondary(look.dark), secondary(look.light))) : AnyShapeStyle(HierarchicalShapeStyle.secondary)
        glassVariant = look.glass.variant
    }

    func color(_ part: KeyPath<Theme.Appearance, ThemeColor>) -> Color {
        Self.color(part, dark: dark, light: light)
    }

    private static var tones: [KeyPath<Theme.Appearance, ThemeColor>] {
        [\.accent, \.good, \.warn, \.bad]
    }

    private static func color(_ part: KeyPath<Theme.Appearance, ThemeColor>, dark: Theme.Appearance, light: Theme.Appearance) -> Color {
        let (one, other) = (dark[keyPath: part], light[keyPath: part])
        if one == other, tones.contains(part) { return one.color }
        return color(one.nsColor, other.nsColor)
    }

    private static func color(_ dark: NSColor, _ light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { SpotTheme.isDark($0) ? dark : light })
    }
}
