import Foundation

public struct Theme: Equatable, Sendable {
    public struct Look: Equatable, Sendable {
        public fileprivate(set) var ink = ThemeColor.none
        public fileprivate(set) var solid = ThemeColor.none
        public fileprivate(set) var onSolid = ThemeColor.none
        public fileprivate(set) var glyphOnSolid = ThemeColor.none
        public fileprivate(set) var glass = ThemeColor.none
        public fileprivate(set) var glassTint = ThemeColor.none
        public fileprivate(set) var cornerFill = ThemeColor.none
        public fileprivate(set) var window = ThemeColor.none
        public fileprivate(set) var preview = ThemeColor.none
        public fileprivate(set) var confirm = ThemeColor.none
        public fileprivate(set) var onConfirm = ThemeColor.none
        public fileprivate(set) var fill = 0.0
        public fileprivate(set) var selected = 0.0
        public fileprivate(set) var disc = 0.0
        public fileprivate(set) var chip = 0.0
        public fileprivate(set) var control = 0.0
        public fileprivate(set) var track = 0.0

        fileprivate static var colours: [String: WritableKeyPath<Look, ThemeColor>] {
            [
                "ink": \.ink, "solid": \.solid, "on-solid": \.onSolid, "glyph-on-solid": \.glyphOnSolid, "glass": \.glass,
                "glass-tint": \.glassTint, "corner-fill": \.cornerFill, "window": \.window, "preview": \.preview,
                "confirm": \.confirm, "on-confirm": \.onConfirm
            ]
        }

        fileprivate static var strengths: [String: WritableKeyPath<Look, Double>] {
            ["fill": \.fill, "selected": \.selected, "disc": \.disc, "chip": \.chip, "control": \.control, "track": \.track]
        }
    }

    public struct Shared: Equatable, Sendable {
        public fileprivate(set) var accent = ThemeColor.none
        public fileprivate(set) var good = ThemeColor.none
        public fileprivate(set) var warn = ThemeColor.none
        public fileprivate(set) var bad = ThemeColor.none
        public fileprivate(set) var pictureRim = ThemeColor.none
        public fileprivate(set) var liftShadow = ThemeColor.none
        public fileprivate(set) var foil = ThemeColor.none
        public fileprivate(set) var publisherRim = ThemeColor.none
        public fileprivate(set) var publisherPillShine = ThemeColor.none
        public fileprivate(set) var engraveOnDark = ThemeColor.none
        public fileprivate(set) var engraveOnLight = ThemeColor.none
        public fileprivate(set) var catchLightOnDark = ThemeColor.none
        public fileprivate(set) var catchLightOnLight = ThemeColor.none
        public fileprivate(set) var secondary = 0.0
        public fileprivate(set) var dragFill = 0.0
        public fileprivate(set) var hover = 0.0
        public fileprivate(set) var menuDim = 0.0
        public fileprivate(set) var liftShadowStrength = 0.0
        public fileprivate(set) var unfocusedCard = 0.0
        public fileprivate(set) var stale = 0.0
        public fileprivate(set) var oldBar = 0.0
        public fileprivate(set) var pressFill = 0.0
        public fileprivate(set) var menuBarTrack = 0.0
        public fileprivate(set) var fadeNear = 0.0
        public fileprivate(set) var fadeFar = 0.0
        public fileprivate(set) var publisherPill = 0.0
        public fileprivate(set) var publisherPillHover = 0.0
        public fileprivate(set) var publisherPillRing = 0.0

        fileprivate static var colours: [String: WritableKeyPath<Shared, ThemeColor>] {
            [
                "accent": \.accent, "good": \.good, "warn": \.warn, "bad": \.bad, "picture-rim": \.pictureRim,
                "lift-shadow": \.liftShadow, "foil": \.foil, "publisher-rim": \.publisherRim,
                "publisher-pill-shine": \.publisherPillShine, "engrave-on-dark": \.engraveOnDark,
                "engrave-on-light": \.engraveOnLight, "catch-light-on-dark": \.catchLightOnDark,
                "catch-light-on-light": \.catchLightOnLight
            ]
        }

        fileprivate static var strengths: [String: WritableKeyPath<Shared, Double>] {
            [
                "secondary": \.secondary, "drag-fill": \.dragFill, "hover": \.hover, "menu-dim": \.menuDim,
                "lift-shadow-strength": \.liftShadowStrength, "unfocused-card": \.unfocusedCard, "stale": \.stale,
                "old-bar": \.oldBar, "press-fill": \.pressFill, "menu-bar-track": \.menuBarTrack, "fade-near": \.fadeNear,
                "fade-far": \.fadeFar, "publisher-pill": \.publisherPill, "publisher-pill-hover": \.publisherPillHover,
                "publisher-pill-ring": \.publisherPillRing
            ]
        }
    }

    public private(set) var dark = Look()
    public private(set) var light = Look()
    public private(set) var shared = Shared()
    public private(set) var faults: [String] = []

    public static var keys: [String] {
        (Array(paths(Look.colours, Shared.colours).keys) + Array(paths(Look.strengths, Shared.strengths).keys)).sorted()
    }

    public init() {}

    public init(unreadable fault: String) {
        faults = [fault]
    }

    public init(text: String, over base: Theme = Theme()) {
        self = base
        let document: ConfigDocument
        do {
            document = try ConfigDocument(text: text)
        } catch {
            faults.append("theme.toml: \((error as? SpotError)?.reason ?? String(describing: error))")
            return
        }
        for key in document.values.keys.sorted() {
            faults.append("theme.toml: \(key) is not a key of a theme.")
        }
        let colours = Self.paths(Look.colours, Shared.colours)
        let strengths = Self.paths(Look.strengths, Shared.strengths)
        for section in document.sections {
            for key in section.keys {
                let name = "[\(section.name)] \(key)"
                if let part = colours[name] {
                    guard case .string(let text)? = section[key], let color = ThemeColor(text: text) else {
                        faults.append("theme.toml: \(name) is a colour such as #00000099.")
                        continue
                    }
                    self[keyPath: part] = color
                } else if let part = strengths[name] {
                    guard let strength = Self.strength(section[key]) else {
                        faults.append("theme.toml: \(name) is a strength from 0 to 1, such as 0.2.")
                        continue
                    }
                    self[keyPath: part] = strength
                } else {
                    faults.append("theme.toml: \(name) is not a key of a theme.")
                }
            }
        }
    }

    private static func paths<Value>(
        _ look: [String: WritableKeyPath<Look, Value>], _ shared: [String: WritableKeyPath<Shared, Value>]
    ) -> [String: WritableKeyPath<Theme, Value>] {
        var all: [String: WritableKeyPath<Theme, Value>] = [:]
        let looks: [(String, WritableKeyPath<Theme, Look>)] = [("dark", \.dark), ("light", \.light)]
        for (section, part) in looks {
            for (key, value) in look { all["[\(section)] \(key)"] = part.appending(path: value) }
        }
        let both: WritableKeyPath<Theme, Shared> = \.shared
        for (key, value) in shared { all["[shared] \(key)"] = both.appending(path: value) }
        return all
    }

    private static func strength(_ value: ConfigDocument.Value?) -> Double? {
        let number: Double? = switch value {
        case .number(let number)?: number
        case .integer(let number)?: Double(number)
        default: nil
        }
        return number.flatMap { (0...1).contains($0) ? $0 : nil }
    }
}
