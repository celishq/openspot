import Foundation

/// The rates that the calc helper keeps between calls: in memory, and in one file for the first ask after the helper starts
/// and for an ask with no internet. Rates older than `freshness` answer at once while new ones come in the background, and
/// with none kept an ask waits for them. A fetch that fails waits `retry` before the next one.
public actor CalcRateCache {
    public static let freshness: TimeInterval = 300
    static let retry: TimeInterval = 60

    /// The helper that keeps the cache, which `openspot calc solve` asks for the rates (K2).
    public static let capability = Capability(name: "calc")

    private let file: URL
    private let now: @Sendable () -> Date
    private let fetch: @Sendable () async throws -> Data
    private var kept: CalcRates?
    private var hasRead = false
    private var refresh: Task<CalcRates?, Never>?
    private var failedAt: Date?

    public init(file: URL, now: @escaping @Sendable () -> Date, fetch: @escaping @Sendable () async throws -> Data) {
        self.file = file
        self.now = now
        self.fetch = fetch
    }

    /// The newest rates it has, or nil when it has none and cannot fetch them.
    public func rates() async -> CalcRates? {
        if !hasRead {
            hasRead = true
            kept = (try? Data(contentsOf: file)).flatMap(CalcRates.init(file:))
        }
        guard let kept else { return await startRefresh()?.value }
        if now().timeIntervalSince(kept.time) > Self.freshness { startRefresh() }
        return kept
    }

    /// Waits for the fetch that runs, if any.
    func settled() async {
        _ = await refresh?.value
    }

    /// Starts a fetch, unless one runs or the last one failed less than `retry` ago, and returns the fetch that runs.
    @discardableResult private func startRefresh() -> Task<CalcRates?, Never>? {
        if let refresh { return refresh }
        if let failedAt, now().timeIntervalSince(failedAt) < Self.retry { return nil }
        let task = Task { () -> CalcRates? in
            defer { refresh = nil }
            guard let data = try? await fetch(), let rates = CalcRates(coinbase: data, time: now()) else {
                failedAt = now()
                return nil
            }
            failedAt = nil
            kept = rates
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? rates.file.write(to: file, options: .atomic)
            return rates
        }
        refresh = task
        return task
    }

    /// The cache of the helper: its file in the caches folder of the person, and its rates from `CalcRates.source`.
    public static var standard: CalcRateCache {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return CalcRateCache(file: caches.appendingPathComponent("openspot/calc-rates.json"), now: { Date() }) {
            var request = URLRequest(url: CalcRates.source, timeoutInterval: 5)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            return try await URLSession.shared.data(for: request).0
        }
    }

    /// Runs as the helper: each call gets the kept rates as `file` writes them, or nothing when it has none.
    public static func serve() -> Never {
        let cache = standard
        capability.serve { _ in await cache.rates()?.file ?? Data() }
    }

    /// Asks the helper for the rates, and starts it when it does not run. Nil when it has none or cannot start.
    public static func ask() -> CalcRates? {
        (try? capability.call(Data("rates".utf8))).flatMap(CalcRates.init(file:))
    }
}
