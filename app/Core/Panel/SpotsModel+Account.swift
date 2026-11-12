import Foundation

/// The account sheet: the steps that create an account, show its words, sign in and sign out, in a sheet that grows out of
/// the search field.
extension SpotsModel {
    /// Opens the account sheet on the step that the account's state calls for, and returns once it closes, with whether
    /// the Mac then holds an account.
    @discardableResult
    public func openAccount() async -> Bool {
        let store = files.account
        dragWatch?.cancel()
        finishPick()
        closeMenu()
        form = nil
        closeList(moving: isShown)
        endReview()
        let moves = isShown
        let host = host
        accountSheet = AccountSheet(flow: AccountFlow(store: store), allows: { await host.allows($0) }) { [weak self] in
            guard let self else { return }
            closeList(moving: isShown)
            endReview()
        }
        reload()
        host.present()
        open(AccountSheet.id, moving: moves)
        await withCheckedContinuation { accountEnd = $0 }
        return (try? store.key()) != nil
    }

    /// Asks for Touch ID or the Mac password, and returns whether the person passed.
    public func allows(_ reason: String) async -> Bool {
        await host.allows(reason)
    }

    /// The account key, which the account sheet makes or brings back when the Mac holds none. Nil when the person closes it.
    func accountKey() async throws -> AccountKey? {
        if let key = try files.account.key() { return key }
        guard await openAccount() else { return nil }
        return try files.account.key()
    }
}
