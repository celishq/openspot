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

    public struct Glass: Equatable, Sendable {
        public enum Variant: String, Equatable, Sendable {
            case clear
            case regular
        }

        public fileprivate(set) var variant = Variant.clear
        public fileprivate(set) var backdropBlur = 0.0
        public fileprivate(set) var fadeReach = 1.0
        public fileprivate(set) var edgeNear = 0.0
        public fileprivate(set) var edgeMiddle = 0.0
        public fileprivate(set) var edgeFar = 0.0

        public var edgeStrengths: [Double] {
            [edgeNear, edgeMiddle, edgeFar]
        }

        fileprivate static var strengths: [String: WritableKeyPath<Glass, Double>] {
            ["edge-near": \.edgeNear, "edge-middle": \.edgeMiddle, "edge-far": \.edgeFar]
        }

        fileprivate static var points: [String: WritableKeyPath<Glass, Double>] {
            ["backdrop-blur": \.backdropBlur]
        }

        fileprivate static var reaches: [String: WritableKeyPath<Glass, Double>] {
            ["fade-reach": \.fadeReach]
        }
    }

    public private(set) var dark = Look()
    public private(set) var light = Look()
    public private(set) var shared = Shared()
    public private(set) var glass = Glass()
    public private(set) var space = Space()
    public private(set) var radius = Radius()
    public private(set) var type = TypeSizes()
    public private(set) var motion = Motion()
    public private(set) var faults: [String] = []

    private static let variant = "[glass] variant"

    public static var keys: [String] {
        (Array(colours.keys) + [strengths, points, reaches, seconds, scales].flatMap(\.keys) + [variant]).sorted()
    }

    public static func kind(of key: String) -> ThemeKind? {
        if colours[key] != nil { return .colour }
        if strengths[key] != nil { return .strength }
        if points[key] != nil { return .points }
        if reaches[key] != nil { return .reach }
        if seconds[key] != nil { return .seconds }
        if scales[key] != nil { return .scale }
        return key == variant ? .variant : nil
    }

    private static var colours: [String: WritableKeyPath<Theme, ThemeColor>] {
        paths(look: Look.colours, shared: Shared.colours)
    }

    private static var strengths: [String: WritableKeyPath<Theme, Double>] {
        paths(look: Look.strengths, shared: Shared.strengths, glass: Glass.strengths)
            .merging(named("motion", \.motion, Motion.strengths)) { one, _ in one }
    }

    private static var points: [String: WritableKeyPath<Theme, Double>] {
        paths(glass: Glass.points)
            .merging(named("space", \.space, Space.points)) { one, _ in one }
            .merging(named("radius", \.radius, Radius.points)) { one, _ in one }
            .merging(named("type", \.type, TypeSizes.points)) { one, _ in one }
    }

    private static var reaches: [String: WritableKeyPath<Theme, Double>] {
        paths(glass: Glass.reaches)
    }

    private static var seconds: [String: WritableKeyPath<Theme, Double>] {
        named("motion", \.motion, Motion.seconds)
    }

    private static var scales: [String: WritableKeyPath<Theme, Double>] {
        named("motion", \.motion, Motion.scales)
    }

    public init() {}

    public init(unreadable fault: String, over base: Theme = Theme()) {
        self = base
        faults.append(fault)
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
        let colours = Self.colours
        let numbers = [(ThemeKind.strength, Self.strengths), (.points, Self.points), (.reach, Self.reaches), (.seconds, Self.seconds), (.scale, Self.scales)]
            .reduce(into: [String: (kind: ThemeKind, part: WritableKeyPath<Theme, Double>)]()) { all, group in
                for (name, part) in group.1 { all[name] = (group.0, part) }
            }
        for section in document.sections {
            for key in section.keys {
                let name = "[\(section.name)] \(key)"
                if let part = colours[name] {
                    guard case .string(let text)? = section[key], let color = ThemeColor(text: text) else {
                        faults.append("theme.toml: \(name) is \(ThemeKind.colour.meaning).")
                        continue
                    }
                    self[keyPath: part] = color
                } else if let (kind, part) = numbers[name] {
                    guard let number = kind.number(section[key]) else {
                        faults.append("theme.toml: \(name) is \(kind.meaning).")
                        continue
                    }
                    self[keyPath: part] = number
                } else if name == Self.variant {
                    guard case .string(let text)? = section[key], let variant = Glass.Variant(rawValue: text) else {
                        faults.append("theme.toml: \(name) is \(ThemeKind.variant.meaning).")
                        continue
                    }
                    glass.variant = variant
                } else {
                    faults.append("theme.toml: \(name) is not a key of a theme.")
                }
            }
        }
    }

    private static func paths<Value>(
        look: [String: WritableKeyPath<Look, Value>] = [:],
        shared: [String: WritableKeyPath<Shared, Value>] = [:],
        glass: [String: WritableKeyPath<Glass, Value>] = [:]
    ) -> [String: WritableKeyPath<Theme, Value>] {
        named("dark", \.dark, look)
            .merging(named("light", \.light, look)) { one, _ in one }
            .merging(named("shared", \.shared, shared)) { one, _ in one }
            .merging(named("glass", \.glass, glass)) { one, _ in one }
    }

    private static func named<Part, Value>(
        _ section: String, _ part: WritableKeyPath<Theme, Part>, _ keys: [String: WritableKeyPath<Part, Value>]
    ) -> [String: WritableKeyPath<Theme, Value>] {
        Dictionary(uniqueKeysWithValues: keys.map { ("[\(section)] \($0.key)", part.appending(path: $0.value)) })
    }
}
