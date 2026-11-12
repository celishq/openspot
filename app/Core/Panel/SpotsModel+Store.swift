import Foundation

/// The store's publish: the spot folder of a spot of the plugins folder is copied into the store folder.
extension SpotsModel {
    /// Publishes a spot of the plugins folder to the store. A spot with no readme opens its listing, which asks for one. A
    /// spot whose files did not change since its last publish writes nothing. A spot with `preview=sample` prints its preview
    /// first, and a Swift spot is compiled into the package.
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
        let folder = files.folder
        do {
            var shared = try SharedSpot(sharing: spot, from: SpotFolder(url: folder.url).keptScan())
            let url = SpotPackage.url(for: folder.fileID(of: spot), in: files.store)
            guard SpotPackage(url: url).hash != SpotPackage.hash(of: shared, in: url.lastPathComponent) else {
                host.confirm("\(spot.name) has no change since its last publish.")
                return .unchanged
            }
            if spot.previewsSample {
                try await SpotListing.capturePreview(of: spot, runs: runs)
                shared = try SharedSpot(sharing: spot, from: SpotFolder(url: folder.url).scan())
            }
            if shared.needsCompile {
                host.work("Compiling \(spot.name)")
                shared = try await shared.compiled()
            }
            try FileManager.default.createDirectory(at: files.store, withIntermediateDirectories: true)
            try SpotPackage.write(shared, to: files.store)
        } catch {
            host.notify("\(spot.name) was not published. \(Self.reason(error))")
            return .failed
        }
        refreshDock(in: files.folder)
        host.confirm("Published \(spot.name) to your store. Its files travel as they are, so check them for secrets before you share it.")
        return .published
    }

    /// Copies the store's package of a spot as one `.spot` file, a zip that a chat can carry, and returns the file. A spot
    /// with no package copies nothing. The zip holds only its own spot folder.
    @discardableResult
    public func sharePackage(_ id: String) -> URL? {
        guard let item = dock.items.first(where: { $0.id == id }), item.publication != nil else { return nil }
        let package = SpotPackage(url: SpotPackage.url(for: files.folder.fileID(of: item.spot), in: files.store))
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared/\(UUID().uuidString)", isDirectory: true)
        let file = place.appendingPathComponent(SharedSpot.fileName(for: item.spot.name))
        do {
            try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
            try package.spot().zip(to: file)
        } catch {
            host.notify("\(item.spot.name) was not copied. \(Self.reason(error))")
            return nil
        }
        host.copy(file)
        host.confirm("Copied \(item.spot.name) as a file. Paste it into a chat or a mail. Its files travel as they are.")
        return file
    }

    /// Copies a prompt that asks the person's agent to write the listing of a spot of the plugins folder.
    public func copyListingWritePrompt(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.isOwn else { return }
        let prompt = host.agentPrompt(for: files.folder.url)
        Task {
            do {
                host.confirm(try await prompt.copy(prompt.listing(item.spot.url)))
            } catch {
                host.notify("The prompt for \(item.spot.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    /// Opens the readme of a spot of the plugins folder in the text editor, and writes its first lines when it has none.
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

    /// Whether the package of each spot of the plugins folder in the store holds its files as they are now.
    nonisolated static func publications(of scan: ScanResult, in folder: SpotFolder, store: URL) -> [String: SpotDock.Publication] {
        var result: [String: SpotDock.Publication] = [:]
        for spot in scan.spots {
            let package = SpotPackage(url: SpotPackage.url(for: folder.fileID(of: spot), in: store))
            guard let hash = package.hash, let shared = try? SharedSpot(sharing: spot, from: scan) else { continue }
            result[spot.id] = SpotPackage.hash(of: shared, in: package.url.lastPathComponent) == hash ? .current : .changed
        }
        return result
    }
}
