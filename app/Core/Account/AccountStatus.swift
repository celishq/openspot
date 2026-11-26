import Foundation

public struct AccountStatus: PrintedRecord, Equatable, Sendable {
    public struct Line: Identifiable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let value: String
    }

    public let signedIn: Bool
    public let npub: String?
    public let handle: String?
    public let since: String?
    public let backedUp: Bool?
    public let sync: Bool?

    public var lines: [Line] {
        [("handle", "Handle", handle), ("npub", "Public key", npub), ("since", "Since", since)].compactMap { id, title, value in value.map { Line(id: id, title: title, value: $0) } }
    }

    var shortNpub: String? {
        npub.map(AccountKey.short)
    }

    var blocks: [[(String, String?)]] {
        [[("item", "account"), ("signedIn", String(signedIn)), ("npub", npub), ("handle", handle), ("since", since), ("backedUp", backedUp.map(String.init)), ("sync", sync.map(String.init))]]
    }
}
