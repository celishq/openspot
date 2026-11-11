import CryptoKit
import Foundation

/// `spots.lock` in the config folder: the source of each spot that `openspot spot add` put in the plugins folder, the
/// commit of a git source, the paths that the spot took, a hash of its files, its uses and the lines of what it can also
/// do and of what runs by itself (N1, N2, Z7). A first add of a spot that uses a power, can do more or runs by itself, and an update that adds a use, change
/// nothing until the person confirms them. Each read, change and write holds a lock beside the file, in the app and in
/// the command alike.
public struct SpotLock: Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let source: String
        public let commit: String?
        public let paths: [String]
        /// The SHA-256 of its files, their paths and whether each one runs.
        public let hash: String?
        /// The uses that its scripts name, in the order of the set.
        public let uses: [SpotUse]?
        /// The lines of what it can also do and of what runs by itself, as its review shows them.
        public var canDo: [String]?

        /// The name of the spot: its first path with no extension.
        public var name: String {
            URL(fileURLWithPath: paths.first ?? source).deletingPathExtension().lastPathComponent
        }

        /// Whether a spot of this ID came from this entry: a script at the top of the folder, or any script in its folder.
        func holds(_ id: String) -> Bool {
            paths.contains { path in
                id == path || id == (path as NSString).deletingPathExtension || id == URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    || id.hasPrefix(path + "/")
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

    /// The hash, the uses and the lines of what it can also do and of what runs by itself, of a spot's paths in a folder.
    private struct Facts {
        let hash: String
        let uses: [SpotUse]
        let canDo: [String]
    }

    private static let name = "spots.lock"
    private static let lockPause: Duration = .milliseconds(20)

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

    /// Puts a spot from a source in the folder, and records it in place of each entry that shared a path with it. A first
    /// add of a spot that the review would show with lines of uses, of what it can also do or of what runs by itself
    /// throws those lines, and a source that the lock has already is an update of its spot, which applies only when it adds
    /// no use; `isConfirmed` lets either through (Z6, Z7). `replaces` names more paths that the new spot may replace, and
    /// `expecting` the files that the source must still hold, such as those a review showed. The old copy goes to `discard`,
    /// as the Trash. Returns the line that tells the person what changed.
    public func add(
        _ source: SpotSource,
        to folder: URL,
        isConfirmed: Bool = false,
        replaces: [String] = [],
        expecting: SharedSpot? = nil,
        discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) async throws -> String {
        try await locked {
            let old = try entries().first { $0.source == source.text }
            var facts: Facts?
            let (commit, paths) = try await source.add(to: folder, at: nil, replacing: (old?.paths ?? []) + replaces, discard: discard) { work, paths in
                if let expecting, try SharedSpot(paths: paths, in: work) != expecting {
                    throw SpotError.fault("The file changed after you looked at it, so Openspot added nothing. Open it again to see it.")
                }
                let new = try Self.facts(of: paths, in: work)
                if old == nil, !isConfirmed, let review = try? ReviewSpot(spot: SharedSpot(paths: paths, in: work), folder: folder), !review.trust.isEmpty {
                    throw SpotError.fault("\(review.name)\n\n\(review.trust)Openspot added nothing. Run `openspot spot add \(source.text) --yes` to add it.")
                }
                if let old, !isConfirmed {
                    let before = old.uses == nil || old.canDo == nil ? try Self.facts(of: old.paths, in: folder) : nil
                    try Self.refuseGrowth(from: old.uses ?? before?.uses ?? [], old.canDo ?? before?.canDo ?? [], to: new, confirm: "openspot spot add \(source.text) --yes")
                }
                facts = new
            }
            let entry = Entry(source: source.text, commit: commit, paths: paths, hash: facts?.hash, uses: facts?.uses, canDo: facts?.canDo)
            try write(try entries().filter { Set($0.paths).isDisjoint(with: paths) && $0.source != source.text } + [entry])
            return old == nil ? entry.added : entry.updated
        }
    }

    /// Adds each spot of the lockfile whose first path the folder lacks, a git one at its commit. One whose files no longer
    /// match the hash comes back only when it adds no use, or when `isConfirmed` (Z7). A spot that cannot come back is a
    /// fault line, and the others still come.
    public func restore(to folder: URL, isConfirmed: Bool = false) async throws -> CommandAnswer {
        try await locked { try await restoring(to: folder, isConfirmed: isConfirmed) }
    }

    private func restoring(to folder: URL, isConfirmed: Bool) async throws -> CommandAnswer {
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
                        try Self.refuseGrowth(from: uses, entry.canDo ?? new.canDo, to: new, confirm: "openspot spot add --yes")
                    }
                    facts = new
                })
                entries[index] = Entry(source: entry.source, commit: entry.commit, paths: entry.paths, hash: facts?.hash, uses: facts?.uses, canDo: facts?.canDo)
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

    /// Throws the lines that name each use, and each line of what it can also do or of what runs by itself, that the new
    /// version adds, with the command that confirms it, when it adds any.
    private static func refuseGrowth(from uses: [SpotUse], _ canDo: [String], to new: Facts, confirm: String) throws {
        let added = new.uses.filter { !uses.contains($0) }
        let more = new.canDo.filter { !canDo.contains($0) }
        guard !added.isEmpty || !more.isEmpty else { return }
        let head = added.isEmpty ? "This version can do more." : "This version adds: \(added.map(\.rawValue).joined(separator: ", "))."
        throw SpotError.fault(([head] + more + ["Openspot kept the one you have. Run `\(confirm)` to update it."]).joined(separator: "\n"))
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
        let review = try? ReviewSpot(spot: SharedSpot(paths: paths, in: folder), folder: FileManager.default.temporaryDirectory.appendingPathComponent("openspot-none", isDirectory: true))
        return Facts(hash: hash.finalize().map { String(format: "%02x", $0) }.joined(), uses: uses, canDo: review?.canDo ?? [])
    }

    /// Moves each path of the entry that holds this ID to the Trash, and drops the entry. A spot that `spot add` did not add
    /// stays, with a fault.
    public func remove(_ id: String, from folder: URL, discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) throws -> Entry {
        let lock = try lockFile()
        defer { close(lock) }
        flock(lock, LOCK_EX)
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

    /// Runs a read, change and write of the file while it holds the lock beside it, which another caller waits for.
    private func locked<T>(_ work: () async throws -> T) async throws -> T {
        let lock = try lockFile()
        defer { close(lock) }
        while flock(lock, LOCK_EX | LOCK_NB) != 0 { try await Task.sleep(for: Self.lockPause) }
        return try await work()
    }

    /// The open file of the lock beside the file, which a close lets go of.
    private func lockFile() throws -> Int32 {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let lock = open(folder.appendingPathComponent(".\(url.lastPathComponent).lock").path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard lock >= 0 else { throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: folder.path]) }
        return lock
    }

    private func write(_ entries: [Entry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(entries).write(to: url, options: .atomic)
    }
}
