import Foundation

public struct SpotLock: Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let source: String
        public let commit: String?
        public let paths: [String]
        public let hash: String?
        public let uses: [SpotUse]?
        public var canDo: [String]?
        public var address: String?
        public var key: String?

        public var name: String {
            SpotID(path: paths.first ?? source).name
        }

        func holds(_ id: String) -> Bool {
            paths.contains { path in
                SpotID(id).isSameFolder(as: SpotID(path: path))
            }
        }

        public init(source: String, commit: String?, paths: [String], hash: String?, uses: [SpotUse]?, canDo: [String]? = nil, address: String? = nil, key: String? = nil) {
            self.source = source
            self.commit = commit
            self.paths = paths
            self.hash = hash
            self.uses = uses
            self.canDo = canDo
            self.address = address
            self.key = key
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                source: values.decode(String.self, forKey: .source),
                commit: values.decodeIfPresent(String.self, forKey: .commit),
                paths: values.decode([String].self, forKey: .paths).map { SpotsFolder.wrapped($0) },
                hash: values.decodeIfPresent(String.self, forKey: .hash),
                uses: values.decodeIfPresent([SpotUse].self, forKey: .uses),
                canDo: values.decodeIfPresent([String].self, forKey: .canDo),
                address: values.decodeIfPresent(String.self, forKey: .address),
                key: values.decodeIfPresent(String.self, forKey: .key)
            )
        }


        var addedLine: String {
            commit.map { "Added \(name) at \($0.prefix(7)).\n" } ?? "Added \(name).\n"
        }

        var updatedLine: String {
            commit.map { "Updated \(name) to \($0.prefix(7)).\n" } ?? "Updated \(name).\n"
        }
    }

    private struct Facts {
        let hash: String
        let uses: [SpotUse]
        let canDo: [String]
        let release: SpotRelease?
    }

    private static let name = "spots.lock"
    private static let lockPause: Duration = .milliseconds(20)

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func standard(environment: [String: String], home: URL = FileManager.default.homeDirectoryForCurrentUser) -> SpotLock {
        SpotLock(url: SpotsFolder.config(environment: environment, home: home).appendingPathComponent(name))
    }

    public func entries() throws -> [Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            throw SpotError.fault("Openspot cannot read \(url.path). Fix it or delete it, then try again.")
        }
        return entries
    }

    public func add(
        _ source: SpotSource,
        to folder: URL,
        isConfirmed: Bool = false,
        replaces: [String] = [],
        expecting: SpotPackage? = nil,
        discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) async throws -> String {
        try await locked {
            let old = try entries().first { $0.source == source.text }
            var facts: Facts?
            let (commit, paths) = try await source.add(to: folder, at: nil, replacing: (old?.paths ?? []) + replaces, discard: discard) { work, paths in
                if let expecting, try SpotPackage(paths: paths, in: work) != expecting {
                    throw SpotError.fault("The file changed after you looked at it, so Openspot added nothing. Open it again to see it.")
                }
                let new = try Self.facts(of: paths, in: work)
                if old == nil, !isConfirmed {
                    let confirm = "Openspot added nothing. Run `openspot spot add \(source.text) --yes` to add it."
                    let review: ReviewSpot
                    do {
                        review = try ReviewSpot(spot: SpotPackage(paths: paths, in: work), folder: folder)
                    } catch {
                        throw SpotError.fault("Openspot cannot review it: \((error as? SpotError)?.reason ?? error.localizedDescription)\n\(confirm)")
                    }
                    if !review.trust.isEmpty { throw SpotError.fault("\(review.name)\n\n\(review.trust)\(confirm)") }
                }
                if let old, !isConfirmed, let key = old.key, new.release?.publicKey != key {
                    throw SpotError.fault("Another key signed this version than the one you have. Openspot kept the one you have. Run `openspot spot add \(source.text) --yes` to update it.")
                }
                if let old, !isConfirmed {
                    let before = old.uses == nil || old.canDo == nil ? try Self.facts(of: old.paths, in: folder) : nil
                    try Self.refuseGrowth(from: old.uses ?? before?.uses ?? [], old.canDo ?? before?.canDo ?? [], to: new, confirm: "openspot spot add \(source.text) --yes")
                }
                facts = new
            }
            let entry = Entry(source: source.text, commit: commit, paths: paths, hash: facts?.hash, uses: facts?.uses, canDo: facts?.canDo, address: facts?.release?.address, key: facts?.release?.publicKey)
            try write(try entries().filter { Set($0.paths).isDisjoint(with: paths) && $0.source != source.text } + [entry])
            return old == nil ? entry.addedLine : entry.updatedLine
        }
    }

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
                entries[index] = Entry(source: entry.source, commit: entry.commit, paths: entry.paths, hash: facts?.hash, uses: facts?.uses, canDo: facts?.canDo, address: facts?.release?.address, key: facts?.release?.publicKey)
                changed[entry.source] = entries[index]
                added += entry.addedLine
            } catch {
                faults += "\(entry.name): \((error as? SpotError)?.reason ?? error.localizedDescription)\n"
            }
        }
        if !changed.isEmpty { try write(try self.entries().map { changed[$0.source] ?? $0 }) }
        if added.isEmpty, faults.isEmpty { added = "Each spot of spots.lock is in the spots folder.\n" }
        return CommandAnswer(output: added, errors: faults, code: faults.isEmpty ? 0 : 1)
    }

    private static func refuseGrowth(from uses: [SpotUse], _ canDo: [String], to new: Facts, confirm: String) throws {
        let added = new.uses.filter { !uses.contains($0) }
        let more = new.canDo.filter { !canDo.contains($0) }
        guard !added.isEmpty || !more.isEmpty else { return }
        let head = added.isEmpty ? "This version can do more." : "This version adds: \(added.map(\.rawValue).joined(separator: ", "))."
        throw SpotError.fault(([head] + more + ["Openspot kept the one you have. Run `\(confirm)` to update it."]).joined(separator: "\n"))
    }

    private static func facts(of paths: [String], in folder: URL) throws -> Facts {
        let spot: SpotPackage?
        let unread: Error?
        do {
            spot = try SpotPackage(paths: paths, in: folder)
            unread = nil
        } catch {
            spot = nil
            unread = error
        }
        let scan = try SpotsFolder(url: folder).scan()
        let names = Set(paths.map { SpotID(path: $0).name })
        let scripts = scan.scripts.filter { script in names.contains(SpotID(script.id).name) }
        let uses = SpotUse.allCases.filter { use in scripts.contains { $0.uses.contains(use) } }
        let canDo: [String]
        do {
            guard let spot else { throw unread ?? SpotError.fault("This file holds no spot.") }
            canDo = try ReviewSpot(spot: spot, folder: FileManager.default.temporaryDirectory.appendingPathComponent("openspot-none", isDirectory: true)).canDo
        } catch {
            canDo = ["Cannot review it: \((error as? SpotError)?.reason ?? error.localizedDescription)"]
        }
        let release = try spot.flatMap { spot in try spot.roots.first.flatMap { try spot.releaseLog(in: $0)?.last } }
        let manifest = try spot.map { SpotManifest($0.files) } ?? SpotManifest(walking: paths, in: folder)
        return Facts(hash: manifest.hash, uses: uses, canDo: canDo, release: release)
    }

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

    private func locked<T>(_ work: () async throws -> T) async throws -> T {
        let lock = try lockFile()
        defer { close(lock) }
        while flock(lock, LOCK_EX | LOCK_NB) != 0 { try await Task.sleep(for: Self.lockPause) }
        return try await work()
    }

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
