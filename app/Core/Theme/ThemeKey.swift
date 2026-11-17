import Foundation

public struct ThemeKey: Hashable, Sendable {
    public let section: String
    public let key: String

    public init(section: String, key: String) {
        self.section = section
        self.key = key
    }

    public var name: String {
        "[\(section)] \(key)"
    }
}
