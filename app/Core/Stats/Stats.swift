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
    let cards: [Spot]
    let byVersion: Bool

    public init(days: [StatsLog.Day], spot: String?, cards: [Spot] = [], byVersion: Bool = false) {
        self.days = days
        self.spot = spot
        self.cards = cards.filter { $0.kind == .widget }
        self.byVersion = byVersion
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
                row(id, version: nil, since: nil, count: count, undeclared: undeclared[id] ?? [:]) { $0.spots[id] }
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
            versions.map { version, kept in row(id, version: version, since: kept.first, count: kept.count, undeclared: [:]) { $0.versions[id]?[version]?.count } }
        }.sorted { ($0.id, $0.since ?? .distantPast) < ($1.id, $1.since ?? .distantPast) }
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
        for day in days {
            for (id, count) in day.spots {
                if let started = count.callers[caller] { runs[id, default: 0] += started }
            }
        }
        return runs.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private var counts: [(id: String, count: StatsLog.Count)] {
        var sums: [String: StatsLog.Count] = [:]
        for day in days {
            for (id, count) in day.spots where spot == nil || spot == id {
                sums[id] = sums[id].map { $0.adding(count) } ?? count
            }
        }
        for card in cards where sums[card.id] == nil && (spot == nil || spot == card.id) {
            var count = StatsLog.Count()
            count.name = card.name
            sums[card.id] = count
        }
        return sums.sorted { ($0.value.cost.cpu, $1.key) > ($1.value.cost.cpu, $0.key) }.map { ($0.key, $0.value) }
    }

    private func row(_ id: String, version: String?, since: Date?, count: StatsLog.Count, undeclared: [String: Int], of day: (StatsLog.Day) -> StatsLog.Count?) -> Row {
        Row(
            id: id, version: version, since: since, count: count,
            acts: days.reversed().map { $0.countsActs ? String(day($0)?.acts ?? 0) : "-" },
            seen: days.count { day($0) != nil },
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
