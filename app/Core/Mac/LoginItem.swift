import Foundation

/// The setting that opens the app at login.
public struct LoginItem: Equatable, Sendable {
    /// The value of its row in a list.
    public static let run = "open_at_login"

    public let isOn: @Sendable () -> Bool
    public let set: @Sendable (Bool) throws -> Void

    public init(isOn: @escaping @Sendable () -> Bool, set: @escaping @Sendable (Bool) throws -> Void) {
        self.isOn = isOn
        self.set = set
    }

    /// Its row in a list.
    var row: TextBlock {
        TextBlock(fields: [
            .init(key: "row", value: Self.run),
            .init(key: "title", value: "Open at login"),
            .init(key: "icon", value: "power"),
            .init(key: "value", value: String(isOn()))
        ])
    }

    /// Turns it on when it is off, and off when it is on.
    func toggle() throws {
        try set(!isOn())
    }

    public static func == (left: LoginItem, right: LoginItem) -> Bool {
        true
    }
}
