import AppKit
import OpenspotCore
import SwiftUI

final class SpotPalette: Sendable {
    let dark: Theme.Appearance
    let light: Theme.Appearance
    let ink: SpotColor
    let solid: SpotColor
    let onSolid: SpotColor
    let glyphOnSolid: SpotColor
    let glass: SpotColor
    let glassTint: SpotColor
    let cornerFill: SpotColor
    let window: SpotColor
    let confirm: SpotColor
    let onConfirm: SpotColor
    let backdropTint: SpotColor
    let cardShadow: SpotColor
    let attachmentFace: SpotColor
    let attachmentTileTop: SpotColor
    let attachmentTileBottom: SpotColor
    let attachmentTileInk: SpotColor
    let highlight: SpotColor
    let accent: SpotColor
    let good: SpotColor
    let warn: SpotColor
    let bad: SpotColor
    let glassInk: AnyShapeStyle
    let glassSecondary: AnyShapeStyle
    let glassVariant: Theme.Glass

    init(_ colours: Theme.Colours) {
        dark = colours.dark
        light = colours.light
        let color = { (part: KeyPath<Theme.Appearance, ThemeColor>) in Self.color(part, dark: colours.dark, light: colours.light) }
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
        cardShadow = color(\.cardShadow)
        attachmentFace = color(\.attachmentFace)
        attachmentTileTop = color(\.attachmentTileTop)
        attachmentTileBottom = color(\.attachmentTileBottom)
        attachmentTileInk = color(\.attachmentTileInk)
        highlight = color(\.highlight)
        accent = color(\.accent)
        good = color(\.good)
        warn = color(\.warn)
        bad = color(\.bad)
        let secondary = { (look: Theme.Appearance) in
            let ink = look.ink.nsColor
            return ink.withAlphaComponent(ink.alphaComponent * look.secondary)
        }
        glassInk = colours.glass.takesInk ? AnyShapeStyle(ink) : AnyShapeStyle(HierarchicalShapeStyle.primary)
        glassSecondary = colours.glass.takesInk ? AnyShapeStyle(Self.color(secondary(colours.dark), secondary(colours.light))) : AnyShapeStyle(HierarchicalShapeStyle.secondary)
        glassVariant = colours.glass
    }

    func ink(onSolid: Bool) -> SpotColor {
        Theme.Appearance.inkKey(onSolid: onSolid) == \.onSolid ? self.onSolid : ink
    }

    func color(_ part: KeyPath<Theme.Appearance, ThemeColor>) -> Color {
        Self.color(part, dark: dark, light: light).color
    }


    private static func color(_ part: KeyPath<Theme.Appearance, ThemeColor>, dark: Theme.Appearance, light: Theme.Appearance) -> SpotColor {
        let (one, other) = (dark[keyPath: part], light[keyPath: part])
        if one == other, tones.contains(part) { return SpotColor(system: one.color) }
        return SpotColor(dark: one.nsColor, light: other.nsColor)
    }

    private static var tones: [KeyPath<Theme.Appearance, ThemeColor>] {
        [\.accent, \.good, \.warn, \.bad]
    }

    static func color(_ dark: NSColor, _ light: NSColor) -> SpotColor {
        SpotColor(dark: dark, light: light)
    }
}
