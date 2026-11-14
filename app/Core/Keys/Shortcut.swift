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
    }

    private static let modifierWords: [(word: String, modifier: Modifiers, mark: String, name: String)] = [
        ("cmd", .command, "⌘", "Command"), ("ctrl", .control, "⌃", "Control"), ("option", .option, "⌥", "Option"), ("shift", .shift, "⇧", "Shift")
    ]
    private static let markOrder: [Modifiers] = [.control, .option, .shift, .command]
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
        var words = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let name = words.popLast() else { return nil }
        var modifiers: Modifiers = []
        for word in words {
            guard let modifier = Self.modifierWords.first(where: { $0.word == word })?.modifier else { return nil }
            modifiers.insert(modifier)
        }
        guard let code = Self.namedCodes[name] ?? CommandKey(name: name)?.code, Self.isHeld(modifiers) else { return nil }
        self.init(name: name, code: code, modifiers: modifiers)
    }

    public init?(code: UInt32, modifiers: Modifiers) {
        guard let name = Self.namedCodes.first(where: { $0.value == code })?.key ?? CommandKey(code: code)?.name,
              Self.isHeld(modifiers) else { return nil }
        self.init(name: name, code: code, modifiers: modifiers)
    }

    private static func isHeld(_ modifiers: Modifiers) -> Bool {
        !modifiers.isDisjoint(with: [.command, .control, .option])
    }

    public var isAppKey: Bool {
        modifiers == .command || modifiers == [.command, .shift]
    }

    public var text: String {
        (Self.modifierWords.filter { modifiers.contains($0.modifier) }.map(\.word) + [name]).joined(separator: "+")
    }

    public var openHint: String {
        "Press `\(label)` to open Openspot"
    }

    public var label: String {
        let marks = Self.markOrder.filter(modifiers.contains).compactMap { held in
            Self.modifierWords.first { $0.modifier == held }?.mark
        }
        return marks.joined() + (name.count == 1 ? name.uppercased() : name.capitalized)
    }

    public func chains(to key: CommandKey, code: UInt32, modifiers: Modifiers) -> Bool {
        modifiers == self.modifiers && code == key.code
    }
}
