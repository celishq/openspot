import Foundation

public struct SpotLock: Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let source: String
        public let commit: String?
        public let paths: [String]
        public let hash: String?
        public let uses: [SpotUse]
        public var canDo: [String]
        public var address: String?
        public var key: String?
        public var version: String?

        public var name: String {
            SpotID(path: paths.first ?? source).name
        }

        func holds(_ id: String) -> Bool {
            paths.contains { path in
                SpotID(id).isSameFolder(as: SpotID(path: path))
            }
        }

        public init(source: String, commit: String?, paths: [String], hash: String?, uses: [SpotUse], canDo: [String] = [], address: String? = nil, key: String? = nil, version: String? = nil) {
            self.source = source
            self.commit = commit
            self.paths = paths
            self.hash = hash
            self.uses = uses
            self.canDo = canDo
            self.address = address
            self.key = key
            self.version = version
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
    public let environment: [String: String]

    public init(url: URL, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.url = url
        self.environment = environment
    }

    public static func standard(environment: [String: String], home: URL = FileManager.default.homeDirectoryForCurrentUser) -> SpotLock {
        SpotLock(url: SpotsFolder.config(environment: environment, home: home).appendingPathComponent(name), environment: environment)
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
        naming: String? = nil,
        asking: String? = nil,
        updating: String? = nil,
        discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) async throws -> String {
        try await locked {
            let old = try entries().first { $0.source == source.text && (naming == nil || $0.paths == [naming]) }
            var facts: Facts?
            let command = updating ?? "openspot spot add \(source.text) --yes"
            let (commit, paths) = try await source.add(to: folder, at: nil, base: environment, naming: naming, replacing: (old?.paths ?? []) + replaces, discard: discard) { work, paths in
                if let expecting, try SpotPackage(paths: paths, in: work) != expecting {
                    throw SpotError.fault("The file changed after you looked at it, so Openspot added nothing. Open it again to see it.")
                }
                let new = try Self.facts(of: paths, in: work)
                if old == nil, !isConfirmed {
                    let confirm = asking ?? "Openspot added nothing. Run `openspot spot add \(source.text) --yes` to add it."
                    let review: ReviewSpot
                    do {
                        review = try ReviewSpot(spot: SpotPackage(paths: paths, in: work), folder: folder, core: SpotsFolder.core(environment: environment))
                    } catch {
                        throw SpotError.fault("Openspot cannot review it: \((error as? SpotError)?.reason ?? error.localizedDescription)\n\(confirm)")
                    }
                    if !review.trust.isEmpty { throw SpotError.fault("\(review.summary)\(confirm)") }
                }
                if let old, !isConfirmed, let key = old.key, new.release?.publicKey != key {
                    throw SpotError.fault("Another key signed this version than the one you have. Openspot kept the one you have. Run `\(command)` to update it.")
                }
                if let old, !isConfirmed {
                    try Self.refuseGrowth(from: old.uses, old.canDo, to: new, confirm: command)
                    let names = Set(paths.map { SpotID(path: $0).name })
                    let changes = BoundChange.lines(of: try SpotsFolder(url: work).scan().scripts.filter { names.contains(SpotID($0.id).name) }, in: folder)
                    if !changes.isEmpty {
                        throw SpotError.fault((changes + ["Openspot kept the one you have. Run `\(command)` to update it."]).joined(separator: "\n"))
                    }
                }
                facts = new
            }
            let entry = Entry(
                source: source.text, commit: commit, paths: paths, hash: facts?.hash, uses: facts?.uses ?? [], canDo: facts?.canDo ?? [], address: facts?.release?.address,
                key: facts?.release?.publicKey, version: try source.version()?.text
            )
            try write(try entries().filter { Set($0.paths).isDisjoint(with: paths) && (naming != nil || $0.source != source.text) } + [entry])
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
                let origin = origin(of: entry)
                var facts: Facts?
                _ = try await origin.add(to: folder, at: entry.commit, base: environment, naming: entry.paths.first, check: { work, paths in
                    let new = try Self.facts(of: paths, in: work)
                    if !isConfirmed, new.hash != entry.hash {
                        try Self.refuseGrowth(from: entry.uses, entry.canDo, to: new, confirm: "openspot spot add --yes")
                    }
                    facts = new
                })
                entries[index] = Entry(
                    source: entry.source, commit: entry.commit, paths: entry.paths, hash: facts?.hash, uses: facts?.uses ?? [], canDo: facts?.canDo ?? [],
                    address: facts?.release?.address, key: facts?.release?.publicKey, version: entry.version == nil ? nil : try origin.version()?.text
                )
                changed[entry.paths.first ?? entry.source] = entries[index]
                added += entry.addedLine
            } catch {
                faults += "\(entry.name): \((error as? SpotError)?.reason ?? error.localizedDescription)\n"
            }
        }
        if !changed.isEmpty { try write(try self.entries().map { changed[$0.paths.first ?? $0.source] ?? $0 }) }
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
        let digest = try spot.map { SpotDigest($0.files) } ?? SpotDigest(walking: paths, in: folder)
        return Facts(hash: digest.hash, uses: uses, canDo: canDo, release: release)
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

    func origin(of entry: Entry) -> SpotSource {
        SpotSource(recorded: entry.source, builtIn: StoreSource.builtIn(environment: environment))
    }

    public func meant(_ id: String, by caller: String) -> String {
        guard let entry = (try? entries())?.first(where: { $0.holds(caller) }), let copy = entry.paths.first else { return id }
        let former = SpotID(path: URL(fileURLWithPath: entry.source).lastPathComponent).name
        let named = SpotID(path: copy).name
        let target = SpotID(id)
        guard former != named, target.name == former else { return id }
        return target.script == former ? named : "\(named)/\(target.script)"
    }

    public func drop(_ id: String) throws {
        let lock = try lockFile()
        defer { close(lock) }
        flock(lock, LOCK_EX)
        let entries = try entries()
        let kept = entries.filter { !$0.holds(id) }
        if kept.count != entries.count { try write(kept) }
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
