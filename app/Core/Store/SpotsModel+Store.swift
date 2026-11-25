import Foundation

extension SpotsModel {
    @discardableResult
    public func publish(_ id: String) async -> SpotPublish {
        guard let spot = ownSpot(id) ?? entries.first(where: { $0.id == id && $0.item == nil })?.spot else { return .notOwn }
        guard origin(of: spot) == .mine else {
            toast(.failure("\(spot.name) comes with Openspot, so the store has it already."))
            return .notOwn
        }
        guard FileManager.default.fileExists(atPath: SpotReadme.url(beside: spot.url).path) else {
            toast(.failure("Write a readme for \(spot.name), then publish it again."))
            return .needsReadme
        }
        let folder = self.folder
        let store = files.store
        do {
            let read = try await Task.detached(priority: .userInitiated) {
                let shared = try SpotPackage(sharing: spot, from: SpotsFolder(url: folder.url).scan())
                return (shared: shared, isCurrent: SpotCatalog.publication(of: shared, in: store) == .current)
            }.value
            var shared = read.shared
            guard !read.isCurrent else {
                toast("\(spot.name) has no change since its last publish.")
                return .unchanged
            }
            if spot.sample != nil {
                try await SpotSample.capture(of: spot, runs: runs)
                shared = try await Task.detached(priority: .userInitiated) { try SpotPackage(sharing: spot, from: SpotsFolder(url: folder.url).scan()) }.value
            }
            guard let released = try await release(shared, named: spot.name) else { return .failed }
            try await Task.detached(priority: .userInitiated) { try released.write(to: store) }.value
        } catch {
            toast(.failure("\(spot.name) was not published. \(Self.reason(error))"))
            return .failed
        }
        toast("Published \(spot.name) to your store. Its files travel as they are, so check them for secrets before you share it.")
        return .published
    }

    func release(_ package: SpotPackage, named name: String) async throws -> SpotPackage? {
        guard let key = try await accountKey() else { return nil }
        if package.needsCompile { toast(.work("Compiling \(name)")) }
        let spots = folder.url
        return try await Task.detached(priority: .userInitiated) { try await package.release(by: key, keepingLogIn: spots) }.value
    }

    var catalog: SpotCatalog {
        SpotCatalog(published: files.store, folder: folder, arrangement: arrangement, stores: Store.all(builtIn: files.examples, config: config))
    }

    func ownSpot(_ id: String) -> Spot? {
        (try? SpotsFolder(url: folder.url).scan())?.files.first { $0.id == id }?.spots.first
    }

    func accountKey() async throws -> AccountKey? {
        let account = Account(store: files.account, allows: { [weak self] reason in await self?.allows(reason) ?? false })
        if let key = try await Task.detached(priority: .userInitiated, operation: { try await account.signing() }).value { return key }
        toast(.failure("Set up your account, then publish again."))
        openSettings(at: .account)
        return nil
    }
}
