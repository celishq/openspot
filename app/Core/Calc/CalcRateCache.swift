import Foundation

/// The rates that the calc helper keeps between calls: in memory, and in one file for the first ask after the helper starts
/// and for an ask with no internet. Rates older than `freshness` answer at once while new ones come in the background, rates
/// older than `staleness` wait a moment for new ones, and with none kept an ask waits for them. A fetch that fails waits
/// `retry` before the next one.
public actor CalcRateCache {
    public static let freshness: TimeInterval = 6 * 3600
    static let retry: TimeInterval = 60
    /// The age of rates for which an ask waits up to `patience` for new ones before it answers with them.
    static let staleness: TimeInterval = 24 * 3600
    static let patience: Duration = .seconds(1)

    /// The helper that keeps the cache, which `openspot calc solve` asks for the rates (K2).
    public static let capability = Capability(name: "calc")

    private let file: URL
    private let now: @Sendable () -> Date
    private let fetch: @Sendable () async throws -> Data
    private var kept: CalcRates?
    private var hasRead = false
    private var refresh: Task<CalcRates?, Never>?
    private var failedAt: Date?
    private var failure: CalcRateFailure?

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
        let age = now().timeIntervalSince(kept.time)
        guard age > Self.freshness, let refresh = startRefresh() else { return kept }
        guard age > Self.staleness else { return kept }
        return await Self.first(of: refresh, within: Self.patience) ?? kept
    }

    /// The newest rates it has, or why it has none.
    public func answer() async -> Result<CalcRates, CalcRateFailure> {
        guard let rates = await rates() else { return .failure(failure ?? .unavailable) }
        return .success(rates)
    }

    /// The value of a fetch, or nil when it takes longer than the time.
    private static func first(of refresh: Task<CalcRates?, Never>, within time: Duration) async -> CalcRates? {
        await withTaskGroup(of: CalcRates?.self) { group in
            group.addTask { await refresh.value }
            group.addTask {
                try? await Task.sleep(for: time)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
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
            let rates: CalcRates
            do {
                guard let read = CalcRates(exchangeAPI: try await fetch(), time: now()), kept.map(read.replaces) ?? true else {
                    throw CalcRateFailure.unavailable
                }
                rates = read
            } catch {
                failedAt = now()
                failure = CalcRateFailure(error)
                return nil
            }
            failedAt = nil
            failure = nil
            kept = rates
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? rates.file.write(to: file, options: .atomic)
            return rates
        }
        refresh = task
        return task
    }

    /// The cache of the helper: its file in the caches folder of the person, and its rates from `CalcRates.sources`.
    public static var standard: CalcRateCache {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return CalcRateCache(file: caches.appendingPathComponent("openspot/calc-rates.json"), now: { Date() }) {
            try await CalcRates.download { url in
                var request = URLRequest(url: url, timeoutInterval: 5)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                return try await URLSession.shared.data(for: request).0
            }
        }
    }

    /// Runs as the helper: each call gets the kept rates as `file` writes them, or `status=<failure>` when it has none.
    public static func serve() -> Never {
        let cache = standard
        capability.serve { _ in
            switch await cache.answer() {
            case .success(let rates): rates.file
            case .failure(let failure): Data(TextBlock(fields: [.init(key: "status", value: failure.rawValue)]).text.utf8)
            }
        }
    }

    /// Asks the helper for the rates, and starts it when it does not run. A helper that cannot start counts as a source that
    /// does not answer.
    public static func ask() -> Result<CalcRates, CalcRateFailure> {
        guard let answer = try? capability.call(Data("rates".utf8)) else { return .failure(.unavailable) }
        if let rates = CalcRates(file: answer) { return .success(rates) }
        let status = TextBlock.blocks(in: String(decoding: answer, as: UTF8.self)).first?.value("status")
        return .failure(status.flatMap(CalcRateFailure.init(rawValue:)) ?? .unavailable)
    }
}
