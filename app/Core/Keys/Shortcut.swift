import Foundation

public struct Shortcut: Hashable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let control = Modifiers(rawValue: 1)
        public static let option = Modifiers(rawValue: 2)
        public static let shift = Modifiers(rawValue: 4)
        public static let command = Modifiers(rawValue: 8)

        public init?(word: String) {
            guard let found = Shortcut.modifierWords.first(where: { $0.word == word.lowercased() }) else { return nil }
            self = found.modifier
        }

        public var word: String? {
            Shortcut.modifierWords.first { $0.modifier == self }?.word
        }

        public var label: String? {
            Shortcut.modifierWords.first { $0.modifier == self }.map { "\($0.mark) \($0.name)" }
        }

        var mark: String? {
            Shortcut.modifierWords.first { $0.modifier == self }?.mark
        }

        public var marks: String {
            KeyText(modifiers: self, name: "").marks
        }

        var makesShortcut: Bool {
            !isDisjoint(with: [.command, .control, .option])
        }

        public static var all: [Modifiers] {
            Shortcut.modifierWords.map(\.modifier)
        }
    }

    private static let modifierWords: [(word: String, modifier: Modifiers, mark: String, name: String)] = [
        ("cmd", .command, "⌘", "Command"), ("ctrl", .control, "⌃", "Control"), ("option", .option, "⌥", "Option"), ("shift", .shift, "⇧", "Shift")
    ]
    private static let namedCodes: [String: UInt32] = ["space": 49, "return": 36, "tab": 48, "left": 123, "right": 124, "down": 125, "up": 126]

    public static let standard = Shortcut(name: "space", code: 49, modifiers: .control)
    public static let fix = Shortcut(name: "o", code: 31, modifiers: [.command, .option])

    public let name: String
    public let code: UInt32
    public let modifiers: Modifiers

    private init(name: String, code: UInt32, modifiers: Modifiers) {
        self.name = name
        self.code = code
        self.modifiers = modifiers
    }

    public init?(text: String) {
        guard let key = KeyText(text: text), let code = Self.namedCodes[key.name] ?? KeyCode(name: key.name)?.code, key.modifiers.makesShortcut else {
            return nil
        }
        self.init(name: key.name, code: code, modifiers: key.modifiers)
    }

    public init?(code: UInt32, modifiers: Modifiers) {
        guard let name = Self.name(of: code), modifiers.makesShortcut else { return nil }
        self.init(name: name, code: code, modifiers: modifiers)
    }

    static func name(of code: UInt32) -> String? {
        namedCodes.first { $0.value == code }?.key ?? KeyCode(code: code)?.name
    }

    static func keyLabel(of code: UInt32) -> String? {
        name(of: code).map { KeyText(modifiers: [], name: $0).keyLabel }
    }

    public var isAppKey: Bool {
        modifiers == .command || modifiers == [.command, .shift]
    }

    public var text: String {
        KeyText(modifiers: modifiers, name: name).text
    }

    public var openHint: String {
        "Press `\(label)` to open Openspot"
    }

    public var label: String {
        KeyText(modifiers: modifiers, name: name).label
    }

    public var keyLabel: String {
        KeyText(modifiers: modifiers, name: name).keyLabel
    }

    public static func caps(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var words = text.lowercased().split(separator: "+").map(String.init)
        let name = words.popLast() ?? ""
        let marks = [("ctrl", "⌃"), ("option", "⌥"), ("shift", "⇧"), ("cmd", "⌘")].filter { words.contains($0.0) }.map(\.1)
        let names = ["space": "Space", "return": "↩", "tab": "⇥", "backspace": "⌫", "escape": "Esc", "left": "←", "right": "→", "up": "↑", "down": "↓", "shake": "Shake"]
        return marks + [names[name] ?? (name.count == 1 ? name.uppercased() : name.capitalized)]
    }
}
