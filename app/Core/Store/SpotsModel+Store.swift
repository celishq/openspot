import Foundation

/// The store's publish: the spot folder of a spot of the spots folder is copied into the store, a folder of spot folders.
extension SpotsModel {
    /// Publishes a spot of the spots folder to the store. A spot with no readme is refused with a toast that asks for one.
    /// A spot whose files did not change since its last publish writes nothing. A spot with `preview=sample` prints its preview
    /// first, a Swift spot is compiled into the package, and the package holds a signed release of it.
    @discardableResult
    public func publish(_ id: String) async -> SpotPublish {
        guard let spot = ownSpot(id) ?? entries.first(where: { $0.id == id && $0.item == nil })?.spot else { return .notOwn }
        guard origin(of: spot) == .mine else {
            host.notify("\(spot.name) comes with Openspot, so the store has it already.")
            return .notOwn
        }
        guard FileManager.default.fileExists(atPath: SpotListing.readme(of: spot.url).path) else {
            host.notify("Write a readme for \(spot.name), then publish it again.")
            return .needsReadme
        }
        let folder = self.folder
        let store = files.store
        do {
            let read = try await Task.detached(priority: .userInitiated) {
                let shared = try SpotPackage(sharing: spot, from: SpotsFolder(url: folder.url).keptScan())
                return (shared: shared, isCurrent: SpotStore.publication(of: shared, in: store) == .current)
            }.value
            var shared = read.shared
            guard !read.isCurrent else {
                host.confirm("\(spot.name) has no change since its last publish.")
                return .unchanged
            }
            if spot.previewsSample {
                try await SpotListing.capturePreview(of: spot, runs: runs)
                shared = try await Task.detached(priority: .userInitiated) { try SpotPackage(sharing: spot, from: SpotsFolder(url: folder.url).scan()) }.value
            }
            guard let released = try await release(shared, named: spot.name) else { return .failed }
            try await Task.detached(priority: .userInitiated) { try released.write(to: store) }.value
        } catch {
            host.notify("\(spot.name) was not published. \(Self.reason(error))")
            return .failed
        }
        host.confirm("Published \(spot.name) to your store. Its files travel as they are, so check them for secrets before you share it.")
        return .published
    }

    /// A spot of the spots folder as a release, signed by the account after a compile that a toast names. Nil when the
    /// person has no account yet, which opens the spot that sets one up.
    func release(_ package: SpotPackage, named name: String) async throws -> SpotPackage? {
        guard let key = try await accountKey() else { return nil }
        if package.needsCompile { host.work("Compiling \(name)") }
        let spots = folder.url
        return try await Task.detached(priority: .userInitiated) { try await package.release(by: key, keepingLogIn: spots) }.value
    }

    /// The store as the panel's arrangement sees it.
    var store: SpotStore {
        SpotStore(url: files.store, folder: folder, arrangement: arrangement)
    }

    /// The spot of a file of the spots folder by its ID, also when Edit Spots turned it off.
    func ownSpot(_ id: String) -> Spot? {
        (try? SpotsFolder(url: folder.url).keptScan())?.files.first { $0.id == id }?.spots.first
    }

    /// The account key. With none, it opens the sheet of the spot that reaches the account key, so the person can set one
    /// up, and returns nil.
    func accountKey() async throws -> AccountKey? {
        let account = files.account
        if let key = try await Task.detached(priority: .userInitiated, operation: { try account.key() }).value { return key }
        if let account = entries.first(where: { $0.spot.reachesAccountKey }) {
            host.present()
            _ = openSheet(account.id)
        }
        host.notify("Set up your account, then publish again.")
        return nil
    }
}
