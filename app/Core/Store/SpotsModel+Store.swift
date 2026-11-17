import Foundation

extension SpotsModel {
    @discardableResult
    public func publish(_ id: String) async -> SpotPublish {
        guard let spot = ownSpot(id) ?? entries.first(where: { $0.id == id && $0.item == nil })?.spot else { return .notOwn }
        guard origin(of: spot) == .mine else {
            host.notify("\(spot.name) comes with Openspot, so the store has it already.")
            return .notOwn
        }
        guard FileManager.default.fileExists(atPath: SpotReadme.url(beside: spot.url).path) else {
            host.notify("Write a readme for \(spot.name), then publish it again.")
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
                host.confirm("\(spot.name) has no change since its last publish.")
                return .unchanged
            }
            if spot.sample != nil {
                try await SpotSample.capture(of: spot, runs: runs)
                shared = try await Task.detached(priority: .userInitiated) { try SpotPackage(sharing: spot, from: SpotsFolder(url: folder.url).scan()) }.value
            }
            guard let released = try await release(shared, named: spot.name, publishing: id) else { return .failed }
            try await Task.detached(priority: .userInitiated) { try released.write(to: store) }.value
        } catch {
            host.notify("\(spot.name) was not published. \(Self.reason(error))")
            return .failed
        }
        host.confirm("Published \(spot.name) to your store. Its files travel as they are, so check them for secrets before you share it.")
        return .published
    }

    func release(_ package: SpotPackage, named name: String, publishing id: String? = nil) async throws -> SpotPackage? {
        guard let key = try await accountKey(publishing: id) else { return nil }
        if package.needsCompile { host.work("Compiling \(name)") }
        let spots = folder.url
        return try await Task.detached(priority: .userInitiated) { try await package.release(by: key, keepingLogIn: spots) }.value
    }

    var catalog: SpotCatalog {
        SpotCatalog(published: files.store, folder: folder, arrangement: arrangement, stores: Store.all(environment: files.environment, config: config), trust: trust.granting(config.trusted))
    }

    func ownSpot(_ id: String) -> Spot? {
        (try? SpotsFolder(url: folder.url).scan())?.files.first { $0.id == id }?.spots.first
    }

    func accountKey(publishing id: String?) async throws -> AccountKey? {
        let account = Account(store: files.account, allows: { [weak self] reason in await self?.allows(reason) ?? false })
        if let key = try await Task.detached(priority: .userInitiated, operation: { try await account.signing() }).value { return key }
        if let account = entries.first(where: { $0.id == AccountSheet.id }) {
            host.present()
            _ = push(FlowSheet(spot: account.id))
            waitingPublish = id
            if id != nil { return nil }
        }
        host.notify("Set up your account, then publish again.")
        return nil
    }

    func publishWaiting() async -> Bool {
        guard let id = waitingPublish else { return false }
        waitingPublish = nil
        await publish(id)
        leaveAccount()
        return true
    }

    private func leaveAccount() {
        guard openSheetID == AccountSheet.id else { return }
        let behind = flow.pages[...flow.index].reversed().prefix { $0.spot == AccountSheet.id }.count
        guard behind <= flow.index else { return }
        popPage(steps: behind)
    }
}
