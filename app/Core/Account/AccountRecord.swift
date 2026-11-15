import Foundation

public struct AccountRecord: Equatable, Sendable {
    private static let wordsPrefix = "nip06 "
    private static let backedUpLine = "backed-up"
    private static let handlePrefix = "handle "
    private static let sincePrefix = "since "

    public let key: AccountKey
    public var isBackedUp: Bool
    public let handle: String?
    public let since: String?

    public init(key: AccountKey, isBackedUp: Bool = false, handle: String? = nil, since: String? = nil) {
        self.key = key
        self.isBackedUp = isBackedUp
        self.handle = handle.flatMap { $0.isEmpty ? nil : $0 }
        self.since = since
    }

    init?(lines: [String]) throws {
        guard let first = lines.first else { return nil }
        let key: AccountKey
        if first.hasPrefix("nsec") {
            key = try AccountKey(nsec: first)
        } else if first.hasPrefix(Self.wordsPrefix) {
            key = try AccountKey(words: first.dropFirst(Self.wordsPrefix.count).split(separator: " ").map(String.init))
        } else {
            return nil
        }
        let rest = lines.dropFirst()
        func value(_ prefix: String) -> String? {
            rest.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        }
        self.init(key: key, isBackedUp: rest.contains(Self.backedUpLine), handle: value(Self.handlePrefix), since: value(Self.sincePrefix))
    }

    var lines: [String] {
        [key.words.map { Self.wordsPrefix + $0.joined(separator: " ") } ?? key.nsec]
            + (isBackedUp ? [Self.backedUpLine] : [])
            + (handle.map { [Self.handlePrefix + $0] } ?? [])
            + (since.map { [Self.sincePrefix + $0] } ?? [])
    }
}
