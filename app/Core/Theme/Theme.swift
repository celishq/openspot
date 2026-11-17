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

        fileprivate static var fields: [String: ThemeField<Look>] {
            [
                "ink": .colour(\.ink), "solid": .colour(\.solid), "on-solid": .colour(\.onSolid), "glyph-on-solid": .colour(\.glyphOnSolid),
                "glass": .colour(\.glass), "glass-tint": .colour(\.glassTint), "corner-fill": .colour(\.cornerFill), "window": .colour(\.window),
                "preview": .colour(\.preview), "confirm": .colour(\.confirm), "on-confirm": .colour(\.onConfirm),
                "fill": .number(.strength, \.fill), "selected": .number(.strength, \.selected), "disc": .number(.strength, \.disc),
                "chip": .number(.strength, \.chip), "control": .number(.strength, \.control), "track": .number(.strength, \.track)
            ]
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

        fileprivate static var fields: [String: ThemeField<Shared>] {
            [
                "accent": .colour(\.accent), "good": .colour(\.good), "warn": .colour(\.warn), "bad": .colour(\.bad),
                "picture-rim": .colour(\.pictureRim), "lift-shadow": .colour(\.liftShadow), "foil": .colour(\.foil),
                "publisher-rim": .colour(\.publisherRim), "publisher-pill-shine": .colour(\.publisherPillShine),
                "engrave-on-dark": .colour(\.engraveOnDark), "engrave-on-light": .colour(\.engraveOnLight),
                "catch-light-on-dark": .colour(\.catchLightOnDark), "catch-light-on-light": .colour(\.catchLightOnLight),
                "secondary": .number(.strength, \.secondary), "drag-fill": .number(.strength, \.dragFill), "hover": .number(.strength, \.hover),
                "menu-dim": .number(.strength, \.menuDim), "lift-shadow-strength": .number(.strength, \.liftShadowStrength),
                "unfocused-card": .number(.strength, \.unfocusedCard), "stale": .number(.strength, \.stale), "old-bar": .number(.strength, \.oldBar),
                "press-fill": .number(.strength, \.pressFill), "menu-bar-track": .number(.strength, \.menuBarTrack),
                "fade-near": .number(.strength, \.fadeNear), "fade-far": .number(.strength, \.fadeFar),
                "publisher-pill": .number(.strength, \.publisherPill), "publisher-pill-hover": .number(.strength, \.publisherPillHover),
                "publisher-pill-ring": .number(.strength, \.publisherPillRing)
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

        fileprivate static var fields: [String: ThemeField<Glass>] {
            [
                "variant": .variant(\.variant), "backdrop-blur": .number(.points, \.backdropBlur), "fade-reach": .number(.reach, \.fadeReach),
                "edge-near": .number(.strength, \.edgeNear), "edge-middle": .number(.strength, \.edgeMiddle), "edge-far": .number(.strength, \.edgeFar)
            ]
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

    public static var keys: [ThemeKey] {
        fields.keys.sorted { $0.name < $1.name }
    }

    public static func kind(of key: ThemeKey) -> ThemeKind? {
        fields[key]?.kind
    }

    public static func accepts(_ value: ConfigDocument.Value, at key: ThemeKey) -> Bool {
        var theme = Theme()
        return fields[key]?.set(value, in: &theme) ?? false
    }

    private static var fields: [ThemeKey: ThemeField<Theme>] {
        [
            named("dark", \.dark, Look.fields), named("light", \.light, Look.fields), named("shared", \.shared, Shared.fields),
            named("glass", \.glass, Glass.fields), named("space", \.space, Space.fields), named("radius", \.radius, Radius.fields),
            named("type", \.type, TypeSizes.fields), named("motion", \.motion, Motion.fields)
        ].reduce(into: [:]) { all, part in all.merge(part) { one, _ in one } }
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
        let fields = Self.fields
        for section in document.sections {
            for key in section.keys {
                let id = ThemeKey(section: section.name, key: key)
                guard let field = fields[id] else {
                    faults.append("theme.toml: \(id.name) is not a key of a theme.")
                    continue
                }
                if !field.set(section[key], in: &self) { faults.append("theme.toml: \(id.name) is \(field.kind.meaning).") }
            }
        }
    }

    private static func named<Part>(_ section: String, _ part: WritableKeyPath<Theme, Part>, _ fields: [String: ThemeField<Part>]) -> [ThemeKey: ThemeField<Theme>] {
        Dictionary(uniqueKeysWithValues: fields.map { (ThemeKey(section: section, key: $0.key), $0.value.on(part)) })
    }
}
