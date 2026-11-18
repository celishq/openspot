import Foundation

struct AccountStatus: PrintedRecord {
    let signedIn: Bool
    let npub: String?
    let handle: String?
    let since: String?
    let backedUp: Bool?
    let sync: Bool?

    var shortNpub: String? {
        npub.map(AccountKey.short)
    }

    var blocks: [[(String, String?)]] {
        [[("text", "account"), ("signedIn", String(signedIn)), ("npub", npub), ("handle", handle), ("since", since), ("backedUp", backedUp.map(String.init)), ("sync", sync.map(String.init))]]
    }
}
