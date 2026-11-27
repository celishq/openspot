import Foundation

public struct AccountStatus: PrintedRecord, Equatable, Sendable {
    public static let line = "Your account signs the spots you publish, so people know that updates come from you."

    public static let about = [
        SettingsFact("Shows an update is yours", "checkmark.seal"),
        SettingsFact("Kept in iCloud Keychain", "icloud"),
        SettingsFact("12 words bring it back", "list.number"),
        SettingsFact("Anyone with the words is you", "eye.slash"),
        SettingsFact("Nobody can reset them", "exclamationmark.triangle", isWarning: true)
    ]

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
