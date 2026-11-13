import Foundation

/// The account that signs what the person publishes: its key, Touch ID, and the spot that sets it up.
extension SpotsModel {
    /// Asks for Touch ID or the Mac password, and returns whether the person passed.
    public func allows(_ reason: String) async -> Bool {
        await host.allows(reason)
    }

    /// The account key. With none, it opens the sheet of the spot that ships in the app and uses the account, so the person
    /// can set one up, and returns nil.
    func accountKey() async throws -> AccountKey? {
        if let key = try files.account.key() { return key }
        if let account = entries.first(where: { $0.spot.isBuiltIn && $0.spot.uses.contains(.account) }) {
            host.present()
            _ = openSheet(account.id)
        }
        host.notify("Set up your account, then publish again.")
        return nil
    }
}
