import Foundation

extension SpotsModel {
    func release(_ package: SpotPackage, named name: String) async throws -> SpotPackage? {
        guard let key = try await accountKey() else { return nil }
        if package.needsCompile { toast(.work("Compiling \(name)")) }
        let spots = folder.url
        return try await Task.detached(priority: .userInitiated) { try await package.release(by: key, keepingLogIn: spots) }.value
    }

    var catalog: SpotCatalog {
        SpotCatalog(folder: folder, arrangement: arrangement, stores: StoreSource.all(builtIn: files.examples, config: config))
    }

    func ownSpot(_ id: String) -> Spot? {
        (try? SpotsFolder(url: folder.url).scan())?.files.first { $0.id == id }?.spots.first
    }

    func accountKey() async throws -> AccountKey? {
        let account = Account(store: files.account, allows: { [weak self] reason in await self?.allows(reason) ?? false })
        if let key = try await Task.detached(priority: .userInitiated, operation: { try await account.signing() }).value { return key }
        if let account = entries.first(where: { $0.id == AccountSheet.id }) {
            host.present()
            _ = push(FlowSheet(spot: account.id))
        }
        toast(.failure("Set up your account, then share again."))
        return nil
    }


}
