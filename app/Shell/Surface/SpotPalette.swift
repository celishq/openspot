import AppKit
import OpenspotCore
import SwiftUI

final class SpotPalette: Sendable {
    let dark: SpotTheme
    let light: SpotTheme
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
        let dark = SpotTheme(look.dark)
        let light = SpotTheme(look.light)
        let color = { (part: KeyPath<SpotTheme, NSColor> & Sendable) in
            let (one, other) = (dark[keyPath: part], light[keyPath: part])
            return Color(nsColor: NSColor(name: nil) { SpotTheme.isDark($0) ? one : other })
        }
        let either = { (part: KeyPath<Theme.Appearance, ThemeColor> & Sendable, drawn: KeyPath<SpotTheme, NSColor> & Sendable) in
            look.dark[keyPath: part] == look.light[keyPath: part] ? look.dark[keyPath: part].color : color(drawn)
        }
        self.dark = dark
        self.light = light
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
        accent = either(\.accent, \.accent)
        good = either(\.good, \.good)
        warn = either(\.warn, \.warn)
        bad = either(\.bad, \.bad)
        glassInk = look.glass.takesInk ? AnyShapeStyle(ink) : AnyShapeStyle(HierarchicalShapeStyle.primary)
        glassSecondary = look.glass.takesInk ? AnyShapeStyle(color(\.secondaryInk)) : AnyShapeStyle(HierarchicalShapeStyle.secondary)
        glassVariant = look.glass.variant
    }
}
