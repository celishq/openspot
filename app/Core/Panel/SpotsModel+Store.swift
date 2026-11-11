import Foundation

/// The store's publish: a spot of the plugins folder becomes a package in the store folder, with its listing.
extension SpotsModel {
    /// Publishes a spot of the plugins folder to the store. A spot with no readme opens its listing, which asks for one. A
    /// spot whose files did not change since its last publish writes nothing. A spot with `preview=sample` prints its preview
    /// first, and a Swift spot is compiled into the package.
    @discardableResult
    public func publish(_ id: String) async -> SpotPublish {
        guard let item = dock.items.first(where: { $0.id == id }) else { return .notOwn }
        let command = item.command
        guard item.isOwn else {
            host.notify("\(command.name) comes with Openspot, so the store has it already.")
            return .notOwn
        }
        let readme = SpotListing.readme(of: command.url)
        guard let text = try? String(contentsOf: readme, encoding: .utf8) else {
            host.notify("Write a readme for \(command.name), then drag it to the store again.")
            if dock.opened != id { openListing(id) }
            return .needsReadme
        }
        let folder = files.folder
        do {
            var spot = try SharedSpot(sharing: command, from: PluginFolder(url: folder.url).scan())
            let hash = SpotPackage.hash(of: spot)
            let url = SpotPackage.url(for: folder.fileID(of: command), in: files.store)
            guard SpotPackage(url: url).hash != hash else {
                host.confirm("\(command.name) has no change since its last publish.")
                return .unchanged
            }
            if command.previewsSample { try await SpotListing.capturePreview(of: command) }
            if spot.needsCompile {
                host.confirm("Compiling \(command.name)")
                spot = try await spot.compiled()
            }
            let preview = try? String(contentsOf: SpotListing.preview(of: command.url), encoding: .utf8)
            try FileManager.default.createDirectory(at: files.store, withIntermediateDirectories: true)
            try SpotPackage.write(spot, hash: hash, title: command.name, description: command.subtitle, readme: text, preview: preview, to: url)
        } catch {
            host.notify("\(command.name) was not published. \(Self.reason(error))")
            return .failed
        }
        refreshDock(in: files.folder)
        host.confirm("Published \(command.name) to your store. Its files travel as they are, so check them for secrets before you share it.")
        return .published
    }

    /// Copies a prompt that asks the person's agent to write the listing of a spot of the plugins folder.
    public func copyListingWritePrompt(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.isOwn, let prompt = agentPrompt else { return }
        Task {
            do {
                host.confirm(try await prompt.copy(prompt.listing(item.command.url)))
            } catch {
                host.notify("The prompt for \(item.command.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    /// Opens the readme of a spot of the plugins folder in the text editor, and writes its first lines when it has none.
    public func writeReadme(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.isOwn else { return }
        let readme = SpotListing.readme(of: item.command.url)
        do {
            if !FileManager.default.fileExists(atPath: readme.path) {
                try "\(item.command.name) … (say what it does and how to use it).\n\nIt runs … (say what it runs, which files it reads or writes, and whether it uses the network).\n".write(to: readme, atomically: true, encoding: .utf8)
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
    static func publications(of scan: ScanResult, in folder: PluginFolder, store: URL) -> [String: SpotDock.Publication] {
        var result: [String: SpotDock.Publication] = [:]
        for command in scan.commands {
            let package = SpotPackage(url: SpotPackage.url(for: folder.fileID(of: command), in: store))
            guard let hash = package.hash, let spot = try? SharedSpot(sharing: command, from: scan) else { continue }
            result[command.id] = SpotPackage.hash(of: spot) == hash ? .current : .changed
        }
        return result
    }
}
