import Foundation

public struct ActionKey: Hashable, Sendable {
    public let name: String
    public let isCommand: Bool
    public let isShift: Bool

    public init(name: String, isCommand: Bool = false, isShift: Bool = false) {
        self.name = name
        self.isCommand = isCommand
        self.isShift = isShift
    }

    public init(typed: String, code: UInt16, isCommand: Bool, isShift: Bool, latin: @autoclosure () -> KeyLayout?) {
        var name = typed.lowercased()
        if isCommand, !name.allSatisfy(\.isASCII), let letter = latin()?.keys[code], letter.isASCII {
            name = String(letter).lowercased()
        }
        self.init(name: name, isCommand: isCommand, isShift: isShift)
    }

    public init?(text: String) {
        guard let key = KeyText(text: text) else { return nil }
        self.init(key)
    }

    public init?(label: String) {
        guard let key = KeyText(label: label) else { return nil }
        self.init(key)
    }

    private init?(_ key: KeyText) {
        guard key.modifiers.isSubset(of: [.command, .shift]) else { return nil }
        let name = key.name
        let isNamed = name == "return" || name == "backspace" || name == "tab" || name == ","
        if name == "escape" {
            guard key.modifiers.isEmpty else { return nil }
        } else {
            guard isNamed || (name.count == 1 && (name.first?.isLetter == true || name.first?.isNumber == true)) else { return nil }
        }
        self.init(name: name, isCommand: key.modifiers.contains(.command), isShift: key.modifiers.contains(.shift))
    }

    private var key: KeyText {
        KeyText(modifiers: Shortcut.Modifiers(rawValue: (isCommand ? Shortcut.Modifiers.command.rawValue : 0) | (isShift ? Shortcut.Modifiers.shift.rawValue : 0)), name: name)
    }

    public var text: String {
        key.text
    }

    public var label: String {
        key.label
    }
}
