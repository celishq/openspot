import Foundation

public struct LoginItem: Equatable, Sendable {
    public let isOn: @Sendable () -> Bool
    public let set: @Sendable (Bool) throws -> Void

    public init(isOn: @escaping @Sendable () -> Bool, set: @escaping @Sendable (Bool) throws -> Void) {
        self.isOn = isOn
        self.set = set
    }

    public static func == (left: LoginItem, right: LoginItem) -> Bool {
        true
    }
}
