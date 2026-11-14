import Foundation

public struct LoginItem: Equatable, Sendable {
    public static let run = "open_at_login"

    public let isOn: @Sendable () -> Bool
    public let set: @Sendable (Bool) throws -> Void

    public init(isOn: @escaping @Sendable () -> Bool, set: @escaping @Sendable (Bool) throws -> Void) {
        self.isOn = isOn
        self.set = set
    }

    var row: TextBlock {
        TextBlock(fields: [
            .init(key: "row", value: Self.run),
            .init(key: "title", value: "Open at login"),
            .init(key: "icon", value: "power"),
            .init(key: "value", value: String(isOn()))
        ])
    }

    func toggle() throws {
        try set(!isOn())
    }

    public static func == (left: LoginItem, right: LoginItem) -> Bool {
        true
    }
}
