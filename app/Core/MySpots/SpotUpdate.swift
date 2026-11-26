import Foundation

public struct SpotUpdate: Sendable {
    public enum State: String, Sendable {
        case current, update, edited
    }

    let lock: SpotLock
    let spots: URL
    let trash: @Sendable (URL) throws -> Void
    let now: @Sendable () -> Date

    public init(places: AppPlaces, clock: RunClock = RunClock()) {
        lock = places.lock
        spots = places.spots.url
        trash = places.trash
        now = clock.now
    }

    public static func state(of entry: SpotLock.Entry, in spots: URL, lock: SpotLock) -> (state: State, version: SpotVersion)? {
        guard let version = entry.version.flatMap(SpotVersion.init(text:)), let path = entry.paths.first else { return nil }
        guard (try? SpotVersion.hash(of: spots.appendingPathComponent(path))) == version.hash else { return (.edited, version) }
        guard let newer = lock.origin(of: entry).find().flatMap({ try? SpotVersion(of: $0) }), newer.isNewer(than: version) else { return (.current, version) }
        return (.update, version)
    }

    public func run(_ id: String?, isConfirmed: Bool, reviewed: String? = nil) async throws -> String {
        guard let id else { return try await all(isConfirmed: isConfirmed) }
        let entry = try entry(id)
        let name = name(of: entry)
        switch Self.state(of: entry, in: spots, lock: lock)?.state {
        case nil:
            throw SpotError.failed(1, "\(name) did not come from a store, so it takes no update.")
        case .edited:
            throw SpotError.failed(1, "\(name) is edited, so it takes no update. Run `openspot store revert \(id)` to replace it with the version of its store.")
        case .current:
            return "\(name) is up to date.\n"
        case .update:
            return try await take(entry, named: name, isConfirmed: isConfirmed, command: "openspot store update \(id) --yes", reviewed: reviewed)
        }
    }

    public func revert(_ id: String, isConfirmed: Bool, reviewed: String? = nil) async throws -> String {
        let entry = try entry(id)
        let name = name(of: entry)
        guard Self.state(of: entry, in: spots, lock: lock)?.state == .edited else { return "\(name) has no edit to revert.\n" }
        let origin = lock.origin(of: entry)
        guard let source = origin.find(), let path = entry.paths.first else {
            throw SpotError.failed(1, "Openspot cannot find the store of \(name), so it kept your edit.")
        }
        _ = try await lock.add(
            origin, to: spots, isConfirmed: isConfirmed, replaces: [path], reviewed: reviewed, naming: path, updating: "openspot store revert \(id) --yes", discard: trash
        )
        return "Reverted \(name) to its version of \(try day(of: source)). Your edited copy is in the Trash.\n"
    }

    public func powers(_ id: String) throws -> [String] {
        let entry = try entry(id)
        guard let source = lock.origin(of: entry).find() else { return [] }
        let review = try ReviewSpot(
            spot: SpotPackage(paths: [source.lastPathComponent], in: source.deletingLastPathComponent()),
            folder: ReviewSpot.noFolder
        )
        let added = review.uses.filter { !entry.uses.contains($0) }
        return (added.isEmpty ? [] : ["Uses \(added.map(\.rawValue).joined(separator: ", "))"]) + review.canDo.filter { !entry.canDo.contains($0) }
    }

    public func readSourceHash(_ id: String) throws -> String? {
        try lock.origin(of: try entry(id)).find().map { try SpotVersion.hash(of: $0) }
    }

    public func name(of id: String) throws -> String {
        name(of: try entry(id))
    }

    @discardableResult
    public func takeEachWithNoNewPower() async -> Bool {
        let before = try? lock.entries()
        for entry in before ?? [] where Self.state(of: entry, in: spots, lock: lock)?.state == .update {
            _ = try? await take(entry, named: name(of: entry), isConfirmed: false, command: "")
        }
        return (try? lock.entries()) != before
    }

    private func all(isConfirmed: Bool) async throws -> String {
        var said = ""
        for entry in try lock.entries() where Self.state(of: entry, in: spots, lock: lock)?.state == .update {
            let id = SpotID(path: entry.paths.first ?? entry.source).name
            let name = name(of: entry)
            do {
                said += try await take(entry, named: name, isConfirmed: isConfirmed, command: "")
            } catch {
                said += "\(name) waits for your yes. Run `openspot store update \(id)` to see what it adds.\n"
            }
        }
        return said.isEmpty ? "Each spot is up to date.\n" : said
    }

    private func take(_ entry: SpotLock.Entry, named name: String, isConfirmed: Bool, command: String, reviewed: String? = nil) async throws -> String {
        let origin = lock.origin(of: entry)
        guard let source = origin.find(), let path = entry.paths.first else { return "" }
        _ = try await lock.add(
            origin, to: spots, isConfirmed: isConfirmed, reviewed: reviewed, naming: path, updating: command, discard: trash
        )
        return "Updated \(name) to its version of \(try day(of: source)).\n"
    }

    private func day(of source: URL) throws -> String {
        try SpotVersion(of: source).day(now: now())
    }

    private func entry(_ id: String) throws -> SpotLock.Entry {
        guard let entry = try lock.entries().first(where: { $0.holds(id) }) else {
            throw SpotError.failed(1, "`\(id)` did not come from a store, so it takes no update. Run `openspot store list` to see each spot.")
        }
        return entry
    }

    private func name(of entry: SpotLock.Entry) -> String {
        let path = entry.paths.first ?? ""
        let found = ((try? SpotsFolder(url: spots).scan())?.files ?? []).first { $0.spots.first?.url.deletingLastPathComponent().lastPathComponent == path }
        return found?.spots.first?.name ?? entry.name
    }
}
