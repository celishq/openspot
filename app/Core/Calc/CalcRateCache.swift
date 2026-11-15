import Foundation

public actor CalcRateCache {
    public static let freshness: TimeInterval = 6 * 3600
    static let retry: TimeInterval = 60
    static let staleness: TimeInterval = 24 * 3600
    static let patience: Duration = .seconds(1)

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

    public func answer() async -> Result<CalcRates, CalcRateFailure> {
        guard let rates = await rates() else { return .failure(failure ?? .unavailable) }
        return .success(rates)
    }

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

    func settled() async {
        _ = await refresh?.value
    }

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

    public static let standard: CalcRateCache = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return CalcRateCache(file: caches.appendingPathComponent("openspot/calc-rates.json"), now: { Date() }) {
            try await CalcRates.download { url in
                var request = URLRequest(url: url, timeoutInterval: 5)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                return try await URLSession.shared.data(for: request).0
            }
        }
    }()
}
