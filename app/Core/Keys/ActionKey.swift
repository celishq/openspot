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
        var parts = text.lowercased().split(separator: "+").map(String.init)
        guard let last = parts.popLast() else { return nil }
        guard parts.allSatisfy({ $0 == "cmd" || $0 == "shift" }) else { return nil }
        if last == "escape" {
            guard parts.isEmpty else { return nil }
            self.init(name: last)
            return
        }
        let isNamed = last == "return" || last == "backspace" || last == ","
        guard isNamed || (last.count == 1 && last.first?.isLetter == true) || (last.count == 1 && last.first?.isNumber == true) else { return nil }
        self.init(name: last, isCommand: parts.contains("cmd"), isShift: parts.contains("shift"))
    }

    public init?(label: String) {
        if label == "Esc" {
            self.init(name: "escape")
            return
        }
        var rest = Substring(label)
        let isCommand = rest.hasPrefix("⌘")
        if isCommand { rest = rest.dropFirst() }
        let isShift = rest.hasPrefix("⇧")
        if isShift { rest = rest.dropFirst() }
        let name: String
        switch rest {
        case "⏎", "↩": name = "return"
        case "⌫": name = "backspace"
        default:
            guard rest.count == 1, let first = rest.first, first.isLetter || first.isNumber else { return nil }
            name = rest.lowercased()
        }
        self.init(name: name, isCommand: isCommand, isShift: isShift)
    }

    public var text: String {
        (isCommand ? "cmd+" : "") + (isShift ? "shift+" : "") + name
    }

    public var label: String {
        let key: String
        switch name {
        case "return": key = "⏎"
        case "backspace": key = "⌫"
        case "escape": return "Esc"
        default: key = name.uppercased()
        }
        return (isCommand ? "⌘" : "") + (isShift ? "⇧" : "") + key
    }
}
