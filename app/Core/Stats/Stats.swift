import Foundation

public struct Stats: Sendable {
    public enum Form: Hashable, Sendable {
        case frame
        case json
        case metrics

        static let metricsWord = "--openmetrics"
    }

    struct Row {
        let id: String
        let version: String?
        let since: Date?
        let count: StatsLog.Count
        let acts: [String]
        let seen: Int
        let undeclared: [String: Int]
    }

    let days: [StatsLog.Day]
    let spot: String?
    let byVersion: Bool
    private let totals: [[String: StatsLog.Count]]

    public init(days: [StatsLog.Day], spot: String?, byVersion: Bool = false) {
        self.days = days
        self.spot = spot
        self.byVersion = byVersion
        totals = days.map(\.spots)
    }

    public func text(_ format: Form) throws -> String {
        switch format {
        case .frame: StatsFrame(stats: self).text
        case .json: try json
        case .metrics: StatsMetrics(stats: self).text
        }
    }

    var rows: [Row] {
        guard byVersion else {
            let undeclared = Dictionary(grouping: uses.filter { !$0.declared }, by: \.spot).mapValues { Dictionary(grouping: $0, by: \.call).mapValues(\.count) }
            return counts.map { id, count in
                row(id, version: nil, since: nil, count: count, undeclared: undeclared[id] ?? [:]) { $1[id] }
            }
        }
        var sums: [String: [String: StatsLog.Version]] = [:]
        for day in days {
            for (id, versions) in day.versions where spot == nil || spot == id {
                for (version, kept) in versions {
                    let older = sums[id]?[version]
                    sums[id, default: [:]][version] = StatsLog.Version(first: [older?.first, kept.first].compactMap { $0 }.min(), count: older.map { kept.count.adding($0.count) } ?? kept.count)
                }
            }
        }
        return sums.flatMap { id, versions in
            versions.map { version, kept in row(id, version: version, since: kept.first, count: kept.count, undeclared: [:]) { day, _ in day.versions[id]?[version]?.count } }
        }.sorted { ($0.id, $0.version == StatsLog.Day.unknownVersion ? .distantPast : $0.since ?? .distantPast) < ($1.id, $1.version == StatsLog.Day.unknownVersion ? .distantPast : $1.since ?? .distantPast) }
    }

    var uses: [StatsLog.Use] {
        days.flatMap(\.uses).filter { spot == nil || $0.spot == spot }.sorted { $0.time > $1.time }
    }

    var searches: [(text: String, count: Int)] {
        guard spot == nil else { return [] }
        var counts: [String: Int] = [:]
        for day in days { counts.merge(day.searches, uniquingKeysWith: +) }
        return counts.sorted { ($1.value, $0.key) < ($0.value, $1.key) }.map { ($0.key, $0.value) }
    }

    func ran(by caller: String) -> [(id: String, runs: Int)] {
        var runs: [String: Int] = [:]
        for spots in totals {
            for (id, count) in spots {
                if let started = count.callers[caller] { runs[id, default: 0] += started }
            }
        }
        return runs.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private var counts: [(id: String, count: StatsLog.Count)] {
        var sums: [String: StatsLog.Count] = [:]
        for spots in totals {
            for (id, count) in spots where spot == nil || spot == id {
                sums[id] = sums[id].map { $0.adding(count) } ?? count
            }
        }
        return sums.sorted { ($0.value.cost.cpu, $1.key) > ($1.value.cost.cpu, $0.key) }.map { ($0.key, $0.value) }
    }

    private func row(_ id: String, version: String?, since: Date?, count: StatsLog.Count, undeclared: [String: Int], of day: (StatsLog.Day, [String: StatsLog.Count]) -> StatsLog.Count?) -> Row {
        let counts = zip(days, totals).map { day($0, $1) }
        return Row(
            id: id, version: version, since: since, count: count,
            acts: zip(days, counts).reversed().map { $0.countsActs ? String($1?.acts ?? 0) : "-" },
            seen: counts.count { $0 != nil },
            undeclared: undeclared
        )
    }

    private var json: String {
        get throws {
            struct Shown: Encodable {
                let day: String
                let countsActs: Bool
                let spots: [String: StatsLog.Count]
                let versions: [String: [String: StatsLog.Version]]?
                let uses: [StatsLog.Use]
                let searches: [String: Int]?
            }
            let kept = days.map { day in
                Shown(
                    day: day.day, countsActs: day.countsActs, spots: day.spots.filter { spot == nil || $0.key == spot },
                    versions: byVersion ? day.versions.filter { spot == nil || $0.key == spot } : nil,
                    uses: day.uses.filter { spot == nil || $0.spot == spot },
                    searches: spot == nil && !day.searches.isEmpty ? day.searches : nil
                )
            }
            return try PrintForm.json(kept, dates: .iso8601)
        }
    }
}
