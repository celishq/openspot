import Foundation
import Synchronization

final class SpotEnv: Sendable {
    struct Kept: Equatable, Sendable {
        let value: String
        let age: Int
    }

    let spot: Spot
    private let cache: SpotCache
    private let fetching: Fetch
    private let isCareful: Bool
    private let locale: Locale
    nonisolated(unsafe) private weak var runs: SpotRuns?
    private let session = Mutex<URLSession?>(nil)

    init(spot: Spot, cache: SpotCache, fetch: Fetch = Fetch(), isCareful: Bool = false, locale: Locale = .autoupdatingCurrent, runs: SpotRuns? = nil) {
        self.spot = spot
        self.cache = cache
        fetching = fetch
        self.isCareful = isCareful
        self.locale = locale
        self.runs = runs
    }

    deinit {
        session.withLock { $0?.finishTasksAndInvalidate() }
    }

    var mac: [String: String] {
        let tag = (locale.identifier.split(separator: "@").first.map(String.init) ?? "en-US").replacingOccurrences(of: "_", with: "-")
        return ["locale": tag, "currency": locale.currency?.identifier ?? "USD"]
    }

    private var owner: String {
        spot.dataName ?? spot.id
    }

    func read(_ name: String) -> Kept? {
        let entry = cache.read(name, of: owner)
        if let age = spot.triggers.fills[name], entry.map({ Date().timeIntervalSince($0.saved) >= age }) ?? true {
            tell { [id = spot.id] in $0.fill(name, of: id) }
        }
        return entry.map { Kept(value: $0.value, age: Int(Date().timeIntervalSince($0.saved).rounded(.down))) }
    }

    func keep(_ value: String, as name: String) throws(SpotCache.Failure) {
        guard try cache.keep(value, as: name, of: owner) else { return }
        tell { [id = spot.id] in $0.cacheChanged(id) }
    }

    func fetch(_ url: String, method: String, headers: [String: String], body: String?) async -> FetchAnswer {
        if isCareful, !spot.uses.contains(.network) {
            return .failed(.refused, "Careful mode stopped \(spot.name), because it reached the network without `network` in the `uses` of its spot.toml. Add it, or turn Careful mode off.")
        }
        if let use = Fetch.use { tell { [spot] in $0.used(use, by: spot) } }
        let session = session.withLock { kept in
            if let kept { return kept }
            let made = fetching.session()
            kept = made
            return made
        }
        return await fetching.answer(url, method: method, headers: headers, body: body, in: session)
    }

    private func tell(_ change: @escaping @MainActor @Sendable (SpotRuns) -> Void) {
        let runs = runs
        Task { @MainActor in runs.map(change) }
    }
}
