import Foundation

/// A key with the modifiers held over it, as a person writes it, such as ctrl+space.
/// It holds cmd, ctrl or option, so that it never takes over normal typing.
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
    }

    private static let modifierWords: [(word: String, modifier: Modifiers, mark: String)] = [
        ("cmd", .command, "⌘"), ("ctrl", .control, "⌃"), ("option", .option, "⌥"), ("shift", .shift, "⇧")
    ]
    private static let markOrder: [Modifiers] = [.control, .option, .shift, .command]
    private static let namedCodes: [String: UInt32] = ["space": 49, "return": 36, "tab": 48, "left": 123, "right": 124, "down": 125, "up": 126]

    /// The key that opens the panel until the person chooses another.
    public static let standard = Shortcut(name: "space", code: 49, modifiers: .control)
    /// The key that opens the link of a failure toast, until the person picks another.
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

    /// Reads a press by its place on the keyboard.
    public init?(code: UInt32, modifiers: Modifiers) {
        guard let name = Self.namedCodes.first(where: { $0.value == code })?.key ?? CommandKey(code: code)?.name,
              Self.isHeld(modifiers) else { return nil }
        self.init(name: name, code: code, modifiers: modifiers)
    }

    private static func isHeld(_ modifiers: Modifiers) -> Bool {
        !modifiers.isDisjoint(with: [.command, .control, .option])
    }

    /// The words for the config file, in one order.
    public var text: String {
        (Self.modifierWords.filter { modifiers.contains($0.modifier) }.map(\.word) + [name]).joined(separator: "+")
    }

    /// The key as the Mac writes it, such as ⌃Space.
    /// The words that tell a person how to open the panel.
    public var openHint: String {
        "Press \(label) to open Openspot"
    }

    public var label: String {
        let marks = Self.markOrder.filter(modifiers.contains).compactMap { held in
            Self.modifierWords.first { $0.modifier == held }?.mark
        }
        return marks.joined() + (name.count == 1 ? name.uppercased() : name.capitalized)
    }

    /// Whether this press holds the same modifiers as this key, and is the letter of a spot.
    public func chains(to key: CommandKey, code: UInt32, modifiers: Modifiers) -> Bool {
        modifiers == self.modifiers && code == key.code
    }
}
