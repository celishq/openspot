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
    let preview: Color
    let confirm: Color
    let onConfirm: Color
    let accent: Color
    let good: Color
    let warn: Color
    let bad: Color
    let pictureRim: Color
    let liftShadow: Color
    let foil: Color
    let publisherRim: Color
    let publisherPillShine: Color
    let engraveOnDark: Color
    let engraveOnLight: Color
    let catchLightOnDark: Color
    let catchLightOnLight: Color
    let shared: Theme.Shared

    init(_ theme: Theme) {
        let dark = SpotTheme(theme.dark)
        let light = SpotTheme(theme.light)
        let color = { (part: KeyPath<SpotTheme, NSColor> & Sendable) in
            let (one, other) = (dark[keyPath: part], light[keyPath: part])
            return Color(nsColor: NSColor(name: nil) { SpotTheme.isDark($0) ? one : other })
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
        preview = color(\.preview)
        confirm = color(\.confirm)
        onConfirm = color(\.onConfirm)
        let shared = theme.shared
        accent = shared.accent.color
        good = shared.good.color
        warn = shared.warn.color
        bad = shared.bad.color
        pictureRim = shared.pictureRim.color
        liftShadow = shared.liftShadow.color
        foil = shared.foil.color
        publisherRim = shared.publisherRim.color
        publisherPillShine = shared.publisherPillShine.color
        engraveOnDark = shared.engraveOnDark.color
        engraveOnLight = shared.engraveOnLight.color
        catchLightOnDark = shared.catchLightOnDark.color
        catchLightOnLight = shared.catchLightOnLight.color
        self.shared = shared
    }
}
