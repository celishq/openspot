import Foundation

/// `spots.lock` in the config folder: the source of each spot that `openspot spot add` put in the plugins folder, the
/// commit of a git source, and the paths at the top of the folder that the spot took (N1, N2).
public struct SpotLock: Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let source: String
        public let commit: String?
        public let paths: [String]

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

    /// Puts a spot from a source in the folder, and records it in place of each entry that shared a path with it.
    public func add(_ source: SpotSource, to folder: URL) async throws -> Entry {
        _ = try entries()
        let (commit, paths) = try await source.add(to: folder, at: nil)
        let entry = Entry(source: source.text, commit: commit, paths: paths)
        try write(try entries().filter { Set($0.paths).isDisjoint(with: paths) } + [entry])
        return entry
    }

    /// Adds each spot of the lockfile whose first path the folder lacks, a git one at its commit. A spot that cannot come
    /// back is a fault line, and the others still come.
    public func restore(to folder: URL) async throws -> CommandAnswer {
        var added = ""
        var faults = ""
        for entry in try entries() where !FileManager.default.fileExists(atPath: folder.appendingPathComponent(entry.paths.first ?? "").path) {
            do {
                let place = URL(fileURLWithPath: "/", isDirectory: true)
                _ = try await SpotSource(text: entry.source, place: place).add(to: folder, at: entry.commit)
                added += entry.added
            } catch {
                faults += "\(entry.name): \((error as? SpotError)?.reason ?? error.localizedDescription)\n"
            }
        }
        if added.isEmpty, faults.isEmpty { added = "Each spot of spots.lock is in the plugins folder.\n" }
        return CommandAnswer(output: added, errors: faults, code: faults.isEmpty ? 0 : 1)
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
