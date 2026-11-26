import Foundation

public enum SettingValue: Equatable, Sendable {
    case unset
    case flag(Bool)
    case shortcut([String])
    case text(String)
    case secret

    init(_ text: String, of kind: SettingRow.Kind) {
        guard !text.isEmpty else {
            self = .unset
            return
        }
        self = switch kind {
        case .toggle: .flag(text == "true")
        case .key: .shortcut(Shortcut.caps(text))
        case .secret: .secret
        case .field, .text, .choice: .text(text)
        }
    }

    public var word: String {
        switch self {
        case .unset: "Not set"
        case .flag(let isOn): isOn ? "On" : "Off"
        case .shortcut(let caps): caps.joined()
        case .text(let text): text
        case .secret: "Set"
        }
    }

    public var isOn: Bool {
        self == .flag(true)
    }

    public var caps: [String] {
        guard case .shortcut(let caps) = self else { return [] }
        return caps
    }

    public var text: String {
        guard case .text(let text) = self else { return "" }
        return text
    }
}
