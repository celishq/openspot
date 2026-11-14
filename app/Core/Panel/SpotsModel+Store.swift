import Foundation

/// The store's publish: the spot folder of a spot of the spots folder is copied into the store, a folder of spot folders.
extension SpotsModel {
    /// Publishes a spot of the spots folder to the store. A spot with no readme opens its listing, which asks for one. A
    /// spot whose files did not change since its last publish writes nothing. A spot with `preview=sample` prints its preview
    /// first, a Swift spot is compiled into the package, and the package holds a signed release of it.
    @discardableResult
    public func publish(_ id: String) async -> SpotPublish {
        guard let item = dock.items.first(where: { $0.id == id }) else { return .notOwn }
        let spot = item.spot
        guard item.isOwn else {
            host.notify("\(spot.name) comes with Openspot, so the store has it already.")
            return .notOwn
        }
        guard FileManager.default.fileExists(atPath: SpotListing.readme(of: spot.url).path) else {
            host.notify("Write a readme for \(spot.name), then drag it to the store again.")
            if dock.opened != id { openListing(id) }
            return .needsReadme
        }
        let folder = self.folder
        let store = files.store
        do {
            let read = try await Task.detached(priority: .userInitiated) {
                let shared = try SpotPackage(sharing: spot, from: SpotsFolder(url: folder.url).keptScan())
                return (shared: shared, isCurrent: Self.publication(of: shared, in: store) == .current)
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
        await refreshDock(in: folder)
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

    /// The account key. With none, it opens the sheet of the spot that reaches the account key, so the person can set one
    /// up, and returns nil.
    func accountKey() async throws -> AccountKey? {
        let account = files.account
        if let key = try await Task.detached(priority: .userInitiated, operation: { try account.key() }).value { return key }
        if let account = entries.first(where: { $0.spot.reachesAccountKey }) {
            host.present()
            _ = push(FlowSheet(spot: account.id))
        }
        host.notify("Set up your account, then publish again.")
        return nil
    }

    /// Copies the store's copy of a spot as one `.spot` file, a zip that a chat can carry, and returns the file. A spot that
    /// the store lacks copies nothing. The zip holds only its own spot folder.
    @discardableResult
    public func sharePackage(_ id: String) -> URL? {
        guard let item = dock.items.first(where: { $0.id == id }), item.publication != nil else { return nil }
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared/\(UUID().uuidString)", isDirectory: true)
        let file = place.appendingPathComponent(SpotPackage.fileName(for: item.spot.name))
        do {
            try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
            try SpotPackage(contentsOf: files.store.appendingPathComponent(SpotID(file: item.spot.url).folderName)).zip(to: file)
        } catch {
            host.notify("\(item.spot.name) was not copied. \(Self.reason(error))")
            return nil
        }
        host.copy(file)
        host.confirm("Copied \(item.spot.name) as a file. Paste it into a chat or a mail. Its files travel as they are.")
        return file
    }

    /// Copies a prompt that asks the person's agent to write the listing of a spot of the spots folder.
    public func copyListingWritePrompt(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.isOwn else { return }
        let prompt = host.agentPrompt(for: folder.url)
        Task {
            do {
                host.confirm(try await prompt.copy(prompt.listing(item.spot.url)))
            } catch {
                host.notify("The prompt for \(item.spot.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    /// Opens the readme of a spot of the spots folder in the text editor, and writes its first lines when it has none.
    public func writeReadme(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.isOwn else { return }
        let readme = SpotListing.readme(of: item.spot.url)
        do {
            if !FileManager.default.fileExists(atPath: readme.path) {
                try "\(item.spot.name) … (say what it does and how to use it).\n\nIt runs … (say what it runs, which files it reads or writes, and whether it uses the network).\n".write(to: readme, atomically: true, encoding: .utf8)
            }
        } catch {
            return host.notify("Openspot cannot write \(readme.path). \(Self.reason(error))")
        }
        Task {
            do {
                _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["open", "-t", readme.path])
            } catch {
                host.notify("Openspot cannot open \(readme.path). \(Self.reason(error))")
            }
        }
    }

    /// Whether the store's copy of each spot of the spots folder holds its files as they are now.
    nonisolated static func publications(of scan: ScanResult, in folder: SpotsFolder, store: URL) -> [String: SpotDock.Publication] {
        var result: [String: SpotDock.Publication] = [:]
        for spot in scan.spots where FileManager.default.fileExists(atPath: store.appendingPathComponent(SpotID(file: spot.url).folderName).path) {
            guard let shared = try? SpotPackage(sharing: spot, from: scan) else { continue }
            result[spot.id] = publication(of: shared, in: store)
        }
        return result
    }

    /// Whether the store holds a copy of a spot's own spot folder with the files that a person writes as they are now, or
    /// older ones, or nil when it holds none. The programs and the views that a publish builds, and the release log, do not count.
    nonisolated static func publication(of spot: SpotPackage, in store: URL) -> SpotDock.Publication? {
        guard let root = spot.roots.first, let stored = try? SpotPackage(contentsOf: store.appendingPathComponent(root)) else { return nil }
        return stored.manifest(of: root).written == spot.manifest(of: root).written ? .current : .changed
    }
}
