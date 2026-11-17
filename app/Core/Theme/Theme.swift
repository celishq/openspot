import Foundation

public struct Theme: Equatable, Sendable {
    public private(set) var choices = ThemeValues()
    public private(set) var exact = ThemeValues()
    public private(set) var look = Look()
    public private(set) var layout = Layout()
    public private(set) var faults: [String] = []

    public static var keys: [ThemeKey] {
        choiceKinds.map(\.key)
    }

    public static var exactKeys: [ThemeKey] {
        exactKinds.map(\.key)
    }

    static let lookColours = ["background", "ink", "accent", "highlight", "good", "warn", "bad"]

    static let choiceKinds: [(key: ThemeKey, kind: ThemeKind)] = ["dark", "light"].flatMap { section in
        lookColours.map { (ThemeKey(section: section, key: $0), ThemeKind.colour) }
    } + Self.lookKinds.map { (ThemeKey(section: "look", key: $0.0), $0.1) }

    private static let lookKinds: [(String, ThemeKind)] = [
        ("glass", .variant), ("backdrop", .backdropLook), ("reach", .backdropReach), ("corner", .points), ("density", .factor),
        ("type", .points), ("speed", .factor)
    ]

    static let exactKinds: [(key: ThemeKey, kind: ThemeKind)] = ["dark", "light"].flatMap { section in
        Appearance.exactKinds.map { (ThemeKey(section: section, key: $0.0), $0.1) }
    } + Layout.exactKinds.map { (ThemeKey(section: "advanced", key: $0.0), $0.1) }

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
        let choiceKinds = Dictionary(uniqueKeysWithValues: Self.choiceKinds.map { ($0.key, $0.kind) })
        let exactKinds = Dictionary(uniqueKeysWithValues: Self.exactKinds.map { ($0.key, $0.kind) })
        var own = ThemeValues()
        exact = ThemeValues()
        for section in document.sections {
            for key in section.keys {
                let id = ThemeKey(section: section.name, key: key)
                guard let kind = choiceKinds[id] ?? exactKinds[id] else {
                    faults.append("theme.toml: \(id.name) is not a key of a theme.")
                    continue
                }
                guard kind.accepts(section[key]) else {
                    faults.append("theme.toml: \(id.name) is \(kind.meaning).")
                    continue
                }
                if choiceKinds[id] != nil { own[id] = section[key] } else { exact[id] = section[key] }
            }
        }
        choices = choices.merging(own)
        look = Look(choices: choices, exact: exact)
        layout = Layout(choices: choices, exact: exact)
    }
}
