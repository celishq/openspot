import Foundation

public struct AccountRecord: Equatable, Sendable {
    private static let backedUpLine = "backed-up"
    private static let namePrefix = "name "
    private static let sincePrefix = "since "

    public let key: AccountKey
    public var isBackedUp: Bool
    public let name: String?
    public let since: String?

    public init(key: AccountKey, isBackedUp: Bool = false, name: String? = nil, since: String? = nil) {
        self.key = key
        self.isBackedUp = isBackedUp
        self.name = name.flatMap { $0.isEmpty ? nil : $0 }
        self.since = since
    }

    init?(lines: [String]) throws {
        guard let first = lines.first, !first.isEmpty else { return nil }
        let key = first.hasPrefix("nsec") ? try AccountKey(nsec: first) : try AccountKey(words: first.split(separator: " ").map(String.init))
        let rest = lines.dropFirst()
        func value(_ prefix: String) -> String? {
            rest.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        }
        self.init(key: key, isBackedUp: rest.contains(Self.backedUpLine), name: value(Self.namePrefix), since: value(Self.sincePrefix))
    }

    var lines: [String] {
        [key.words?.joined(separator: " ") ?? key.nsec]
            + (isBackedUp ? [Self.backedUpLine] : [])
            + (name.map { [Self.namePrefix + $0] } ?? [])
            + (since.map { [Self.sincePrefix + $0] } ?? [])
    }
}
