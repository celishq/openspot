import Foundation

/// A key with its modifiers, as a script names it, such as cmd+return or cmd+shift+n.
public struct ActionKey: Hashable, Sendable {
    public let name: String
    public let isCommand: Bool
    public let isShift: Bool

    public init(name: String, isCommand: Bool = false, isShift: Bool = false) {
        self.name = name
        self.isCommand = isCommand
        self.isShift = isShift
    }

    public init?(text: String) {
        var parts = text.lowercased().split(separator: "+").map(String.init)
        guard let last = parts.popLast() else { return nil }
        guard parts.allSatisfy({ $0 == "cmd" || $0 == "shift" }) else { return nil }
        let isNamed = last == "return" || last == "backspace"
        guard isNamed || (last.count == 1 && last.first?.isLetter == true) || (last.count == 1 && last.first?.isNumber == true) else { return nil }
        self.init(name: last, isCommand: parts.contains("cmd"), isShift: parts.contains("shift"))
    }

    /// The key as the Mac writes it, such as ⌘⇧N.
    public var label: String {
        let key: String
        switch name {
        case "return": key = "⏎"
        case "backspace": key = "⌫"
        default: key = name.uppercased()
        }
        return (isCommand ? "⌘" : "") + (isShift ? "⇧" : "") + key
    }
}
