import CryptoKit
import Foundation

/// `spots.lock` in the config folder: the source of each spot that `openspot spot add` put in the plugins folder, the
/// commit of a git source, the paths at the top of the folder that the spot took, a hash of its files and its uses (N1,
/// N2, Z7). An update that adds a use changes nothing until the person confirms it.
public struct SpotLock: Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let source: String
        public let commit: String?
        public let paths: [String]
        /// The SHA-256 of its files, their paths and whether each one runs.
        public let hash: String?
        /// The uses that its scripts name, in the order of the set.
        public let uses: [SpotUse]?

        /// The name of the spot: its first path with no extension.
        public var name: String {
            URL(fileURLWithPath: paths.first ?? source).deletingPathExtension().lastPathComponent
        }

        /// Whether a spot of this ID came from this entry: a script at the top of the folder, or any script in its folder.
        func holds(_ id: String) -> Bool {
            paths.contains { path in
                id == path || id == URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent || id.hasPrefix(path + "/")
            }
        }

        /// The line that tells the person what came in.
        var added: String {
            commit.map { "Added \(name) at \($0.prefix(7)).\n" } ?? "Added \(name).\n"
        }

        /// The line that tells the person what an update brought.
        var updated: String {
            commit.map { "Updated \(name) to \($0.prefix(7)).\n" } ?? "Updated \(name).\n"
        }
    }

    /// The hash and the uses of a spot's paths in a folder.
    private struct Facts {
        let hash: String
        let uses: [SpotUse]
    }

    private static let name = "spots.lock"

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func standard(environment: [String: String], home: URL = FileManager.default.homeDirectoryForCurrentUser) -> SpotLock {
        SpotLock(url: SpotFolder.config(environment: environment, home: home).appendingPathComponent(name))
    }

    /// Each entry, in the order that the spots came in. No file has none.
    public func entries() throws -> [Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            throw SpotError.fault("Openspot cannot read \(url.path). Fix it or delete it, then try again.")
        }
        return entries
    }

    /// Puts a spot from a source in the folder, and records it in place of each entry that shared a path with it. A source
    /// that the lock has already is an update of its spot, which applies only when it adds no use, or when `isConfirmed`
    /// (Z7). The old copy goes to `discard`, as the Trash. Returns the line that tells the person what changed.
    public func add(
        _ source: SpotSource,
        to folder: URL,
        isConfirmed: Bool = false,
        discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) async throws -> String {
        let old = try entries().first { $0.source == source.text }
        var facts: Facts?
        let (commit, paths) = try await source.add(to: folder, at: nil, replacing: old?.paths ?? [], discard: discard) { work, paths in
            let new = try Self.facts(of: paths, in: work)
            if let old, !isConfirmed {
                try Self.refuseGrowth(from: old.uses ?? Self.facts(of: old.paths, in: folder).uses, to: new.uses, confirm: "openspot spot add \(source.text) --yes")
            }
            facts = new
        }
        let entry = Entry(source: source.text, commit: commit, paths: paths, hash: facts?.hash, uses: facts?.uses)
        try write(try entries().filter { Set($0.paths).isDisjoint(with: paths) && $0.source != source.text } + [entry])
        return old == nil ? entry.added : entry.updated
    }

    /// Adds each spot of the lockfile whose first path the folder lacks, a git one at its commit. One whose files no longer
    /// match the hash comes back only when it adds no use, or when `isConfirmed` (Z7). A spot that cannot come back is a
    /// fault line, and the others still come.
    public func restore(to folder: URL, isConfirmed: Bool = false) async throws -> CommandAnswer {
        var added = ""
        var faults = ""
        var entries = try entries()
        var changed: [String: Entry] = [:]
        for (index, entry) in entries.enumerated() where !FileManager.default.fileExists(atPath: folder.appendingPathComponent(entry.paths.first ?? "").path) {
            do {
                let place = URL(fileURLWithPath: "/", isDirectory: true)
                var facts: Facts?
                _ = try await SpotSource(text: entry.source, place: place).add(to: folder, at: entry.commit, check: { work, paths in
                    let new = try Self.facts(of: paths, in: work)
                    if !isConfirmed, new.hash != entry.hash, let uses = entry.uses {
                        try Self.refuseGrowth(from: uses, to: new.uses, confirm: "openspot spot add --yes")
                    }
                    facts = new
                })
                entries[index] = Entry(source: entry.source, commit: entry.commit, paths: entry.paths, hash: facts?.hash, uses: facts?.uses)
                changed[entry.source] = entries[index]
                added += entry.added
            } catch {
                faults += "\(entry.name): \((error as? SpotError)?.reason ?? error.localizedDescription)\n"
            }
        }
        if !changed.isEmpty { try write(try self.entries().map { changed[$0.source] ?? $0 }) }
        if added.isEmpty, faults.isEmpty { added = "Each spot of spots.lock is in the plugins folder.\n" }
        return CommandAnswer(output: added, errors: faults, code: faults.isEmpty ? 0 : 1)
    }

    /// Throws the line that names each use that the new version adds, with the command that confirms it, when it adds one.
    private static func refuseGrowth(from old: [SpotUse], to new: [SpotUse], confirm: String) throws {
        let added = new.filter { !old.contains($0) }
        guard !added.isEmpty else { return }
        throw SpotError.fault("This version adds: \(added.map(\.rawValue).joined(separator: ", ")).\nOpenspot kept the one you have. Run `\(confirm)` to update it.")
    }

    /// The hash of the files under the paths in a folder, and the uses that their scripts name.
    private static func facts(of paths: [String], in folder: URL) throws -> Facts {
        var hash = SHA256()
        var files: [(path: String, url: URL)] = []
        for path in paths {
            let top = folder.appendingPathComponent(path)
            var isFolder: ObjCBool = false
            guard FileManager.default.fileExists(atPath: top.path, isDirectory: &isFolder) else { continue }
            guard isFolder.boolValue else {
                files.append((path, top))
                continue
            }
            for inner in FileManager.default.subpaths(atPath: top.path) ?? [] {
                let url = top.appendingPathComponent(inner)
                var isInner: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isInner), !isInner.boolValue { files.append(("\(path)/\(inner)", url)) }
            }
        }
        for file in files.sorted(by: { $0.path < $1.path }) {
            hash.update(data: Data("\(file.path)\0\(FileManager.default.isExecutableFile(atPath: file.url.path))\0".utf8))
            hash.update(data: try Data(contentsOf: file.url))
        }
        let scan = try SpotFolder(url: folder).scan()
        let scripts = scan.scripts.filter { script in paths.contains { script.id == ($0 as NSString).deletingPathExtension || script.id.hasPrefix($0 + "/") } }
        let uses = SpotUse.allCases.filter { use in scripts.contains { $0.uses.contains(use) } }
        return Facts(hash: hash.finalize().map { String(format: "%02x", $0) }.joined(), uses: uses)
    }

    /// Moves each path of the entry that holds this ID to the Trash, and drops the entry. A spot that `spot add` did not add
    /// stays, with a fault.
    public func remove(_ id: String, from folder: URL, discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws -> Entry {
        var entries = try entries()
        guard let index = entries.firstIndex(where: { $0.holds(id) }) else {
            throw SpotError.fault("`openspot spot add` did not add \(id), so Openspot leaves it. Move its file to the Trash to remove it.")
        }
        let entry = entries.remove(at: index)
        for path in entry.paths {
            let file = folder.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: file.path) { try discard(file) }
        }
        try write(entries)
        return entry
    }

    private func write(_ entries: [Entry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(entries).write(to: url, options: .atomic)
    }
}
