@MainActor
struct KeyRow {
    let name: String?
    let isCommand: Bool?
    let isShift: Bool?
    let glyph: String?
    let words: String?
    let act: @MainActor (ActionKey) -> Bool?

    init(_ name: String, command: Bool? = false, shift: Bool? = false, glyph: String? = nil, words: String? = nil, act: @escaping @MainActor (ActionKey) -> Bool?) {
        self.name = name
        isCommand = command
        isShift = shift
        self.glyph = glyph
        self.words = words
        self.act = act
    }

    private init(words: String?, act: @escaping @MainActor (ActionKey) -> Bool?) {
        name = nil
        isCommand = nil
        isShift = nil
        glyph = nil
        self.words = words
        self.act = act
    }

    static func any(_ act: @escaping @MainActor (ActionKey) -> Bool?) -> KeyRow {
        KeyRow(words: nil, act: act)
    }

    static func words(_ words: String) -> KeyRow {
        KeyRow(words: words) { _ in nil }
    }

    func takes(_ key: ActionKey) -> Bool {
        guard let name else { return words == nil }
        return key.name == name && (isCommand ?? key.isCommand) == key.isCommand && (isShift ?? key.isShift) == key.isShift
    }

    var hint: String? {
        guard let words else { return nil }
        guard let name else { return words }
        return "\(glyph ?? ActionKey(name: name, isCommand: isCommand ?? false, isShift: isShift ?? false).label) \(words)"
    }

    static func hint(of rows: [KeyRow]) -> String {
        rows.compactMap(\.hint).joined(separator: "   ")
    }
}
