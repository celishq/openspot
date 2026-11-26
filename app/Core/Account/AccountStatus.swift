import Foundation

public struct AccountStatus: PrintedRecord, Equatable, Sendable {
    public let signedIn: Bool
    public let npub: String?
    public let handle: String?
    public let since: String?
    public let backedUp: Bool?
    public let sync: Bool?

    public var shortNpub: String? {
        npub.map(AccountKey.short)
    }

    var blocks: [[(String, String?)]] {
        [[("item", "account"), ("signedIn", String(signedIn)), ("npub", npub), ("handle", handle), ("since", since), ("backedUp", backedUp.map(String.init)), ("sync", sync.map(String.init))]]
    }
}
