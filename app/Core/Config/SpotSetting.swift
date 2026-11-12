import Foundation

/// A value that the person chose for one spot, which its script keeps through `openspot setting` (protocol: Settings).
public struct SpotSetting: Hashable, Sendable {
    public let spot: String
    public let key: String
    public let value: String

    public init(spot: String, key: String, value: String) {
        self.spot = spot
        self.key = key
        self.value = value
    }

    /// The lines of this value in the config file.
    var text: String {
        "[[settings]]\nspot = \(Self.quoted(spot))\nkey = \(Self.quoted(key))\nvalue = \(Self.quoted(value))"
    }

    private static func quoted(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}
