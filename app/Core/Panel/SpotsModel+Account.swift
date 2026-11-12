import Foundation

/// The account sheet: the steps that create an account, show its words, sign in and sign out, in a sheet that grows out of
/// the search field.
extension SpotsModel {
    /// Opens the account sheet on a step, and returns once it closes, with whether the Mac then holds an account. The words
    /// of a kept key and a sign-out first ask for Touch ID or the Mac password.
    @discardableResult
    public func openAccount(_ step: AccountFlow.Step) async -> Bool {
        let store = files.account
        if step == .words || step == .signOut {
            guard (try? store.key()) != nil else { return false }
            guard await host.allows(step == .words ? "show your account words" : "sign out of your account") else { return true }
        }
        dragWatch?.cancel()
        finishPick()
        closeMenu()
        form = nil
        closeList(moving: isShown)
        endReview()
        let moves = isShown
        accountSheet = AccountSheet(flow: AccountFlow(store: store, step: step)) { [weak self] in
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

    /// The account key, which the account sheet makes or brings back when the Mac holds none. Nil when the person closes it.
    func accountKey() async throws -> AccountKey? {
        if let key = try files.account.key() { return key }
        guard await openAccount(.choose) else { return nil }
        return try files.account.key()
    }
}
