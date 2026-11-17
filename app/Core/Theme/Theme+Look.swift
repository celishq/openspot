import Foundation

extension Theme {
    public struct Look: Equatable, Sendable {
        public let dark: Appearance
        public let light: Appearance
        public let glass: Glass

        public init() {
            self.init(choices: ThemeValues(), exact: ThemeValues())
        }

        init(choices: ThemeValues, exact: ThemeValues) {
            glass = Glass(variant: choices.word("look", "glass") ?? .clear)
            dark = Appearance(isDark: true, glass: glass.variant, choices: choices, exact: exact)
            light = Appearance(isDark: false, glass: glass.variant, choices: choices, exact: exact)
        }
    }

    public struct Glass: Equatable, Sendable {
        public enum Variant: String, Equatable, Sendable {
            case clear
            case regular
        }

        public let variant: Variant

        public var takesInk: Bool {
            variant == .regular
        }
    }

    public struct Appearance: Equatable, Sendable {
        public let background: ThemeColor
        public let ink: ThemeColor
        public let accent: ThemeColor
        public let highlight: ThemeColor
        public let good: ThemeColor
        public let warn: ThemeColor
        public let bad: ThemeColor
        public let solid: ThemeColor
        public let onSolid: ThemeColor
        public let glyphOnSolid: ThemeColor
        public let glass: ThemeColor
        public let glassTint: ThemeColor
        public let cornerFill: ThemeColor
        public let window: ThemeColor
        public let confirm: ThemeColor
        public let onConfirm: ThemeColor
        public let backdropTint: ThemeColor
        public let fill: Double
        public let selected: Double
        public let disc: Double
        public let chip: Double
        public let control: Double
        public let track: Double
        public let secondary: Double

        static let exactKinds: [(String, ThemeKind)] = [
            "solid", "on-solid", "glyph-on-solid", "glass-tint", "corner-fill", "window", "confirm", "on-confirm", "backdrop-tint"
        ].map { ($0, ThemeKind.colour) } + ["fill", "selected", "disc", "chip", "control", "track", "secondary"].map { ($0, ThemeKind.strength) }

        private static let openspot = (
            dark: (background: HexColor(text: "#000000")!, ink: HexColor(text: "#FFFFFF")!,
                   strengths: ["fill": 0.1, "selected": 0.22, "disc": 0.2, "chip": 0.25, "control": 0.2, "track": 0.2]),
            light: (background: HexColor(text: "#FFFFFF")!, ink: HexColor(text: "#1C1C1C")!,
                    strengths: ["fill": 0.08, "selected": 0.12, "disc": 0.0, "chip": 0.1, "control": 0.09, "track": 0.12])
        )
        private static let leastSecondary = 0.7
        private static let textContrast = 4.5
        private static let lightestBackdrop = HexColor(red: 1, green: 1, blue: 1)

        init(isDark: Bool, glass variant: Glass.Variant, choices: ThemeValues, exact: ThemeValues) {
            let section = isDark ? "dark" : "light"
            let anchor = isDark ? Self.openspot.dark : Self.openspot.light
            let chosen = { (key: String) in choices.colour(section, key) }
            let pinned = { (key: String) in exact.colour(section, key) }
            background = chosen("background") ?? .hex(anchor.background)
            ink = chosen("ink") ?? .hex(anchor.ink)
            accent = chosen("accent") ?? .accent
            highlight = chosen("highlight") ?? ink
            good = chosen("good") ?? .green
            warn = chosen("warn") ?? .orange
            bad = chosen("bad") ?? .red
            solid = pinned("solid") ?? highlight
            onSolid = pinned("on-solid") ?? solid.legible(background, or: ink)
            glyphOnSolid = pinned("glyph-on-solid") ?? onSolid
            glassTint = pinned("glass-tint") ?? background.with(alpha: variant == .regular ? 0.9 : 0.45)
            glass = variant == .regular ? glassTint : background.with(alpha: isDark ? 0 : 0.5)
            cornerFill = pinned("corner-fill") ?? background.mixed(with: ink, by: isDark ? 0.2 : 0.02)
            window = pinned("window") ?? background.mixed(with: ink, by: isDark ? 0.16 : 0.08)
            confirm = pinned("confirm") ?? bad
            onConfirm = pinned("on-confirm") ?? confirm.legible(background, or: ink)
            backdropTint = pinned("backdrop-tint") ?? background.with(alpha: isDark ? 0.6 : 0.5)
            let (ground, mark) = (background.sample, ink.sample)
            let strength = { (key: String) in
                exact.number(section, key) ?? Self.strength(anchor.strengths[key] ?? 0, keeping: (anchor.background, anchor.ink), on: ground, of: mark)
            }
            fill = strength("fill")
            selected = strength("selected")
            disc = strength("disc")
            chip = strength("chip")
            control = strength("control")
            track = strength("track")
            let surface = variant == .regular ? Self.lightestBackdrop.mixed(with: ground, by: 0.9) : ground
            secondary = exact.number(section, "secondary") ?? Self.secondary(of: mark, on: surface)
        }

        private static func strength(_ anchor: Double, keeping reference: (HexColor, HexColor), on ground: HexColor, of mark: HexColor) -> Double {
            guard anchor > 0 else { return 0 }
            let target = step(anchor, of: reference.1, on: reference.0)
            var strength = anchor
            for _ in 0..<4 {
                let now = step(strength, of: mark, on: ground)
                guard now > 0 else { break }
                strength = min(1, strength * (target / now))
            }
            return strength
        }

        private static func step(_ strength: Double, of mark: HexColor, on ground: HexColor) -> Double {
            let parts = [ground.red, ground.green, ground.blue]
            let over = HexColor.mix(parts, [mark.red, mark.green, mark.blue], by: strength)
            return abs(HexColor.lightness(of: over) - HexColor.lightness(of: parts))
        }

        private static func secondary(of mark: HexColor, on surface: HexColor) -> Double {
            var strength = leastSecondary
            while strength < 1, surface.mixed(with: mark, by: strength).contrast(with: surface) < textContrast { strength += 0.01 }
            return (min(strength, 1) * 100).rounded() / 100
        }
    }
}
