import Foundation

public struct StatsReport: Sendable {
    let days: [SpotUsage.Day]
    let spot: String?
    let cards: [Spot]

    public init(days: [SpotUsage.Day], spot: String?, cards: [Spot] = []) {
        self.days = days
        self.spot = spot
        self.cards = cards.filter { $0.kind == .widget }
    }

    public func text(_ format: PrintForm) throws -> String {
        switch format {
        case .frame: frame
        case .json: try json
        }
    }

    private var counts: [(id: String, count: SpotUsage.Count)] {
        var sums: [String: SpotUsage.Count] = [:]
        for day in days {
            for (id, count) in day.spots where spot == nil || spot == id {
                sums[id] = sums[id].map { $0.adding(count) } ?? count
            }
        }
        for card in cards where sums[card.id] == nil && (spot == nil || spot == card.id) {
            var count = SpotUsage.Count()
            count.name = card.name
            sums[card.id] = count
        }
        return sums.sorted { ($0.value.cost.cpu, $1.key) > ($1.value.cost.cpu, $0.key) }.map { ($0.key, $0.value) }
    }

    private var uses: [SpotUsage.Use] {
        days.flatMap(\.uses).filter { spot == nil || $0.spot == spot }.sorted { $0.time > $1.time }
    }

    private func ran(by caller: String, in counts: [(id: String, count: SpotUsage.Count)]) -> [(id: String, runs: Int)] {
        counts.compactMap { id, count in count.callers[caller].map { (id, $0) } }.sorted { $0.id < $1.id }
    }

    private func acts(of id: String) -> [String] {
        days.reversed().map { day in day.countsActs ? String(day.spots[id]?.acts ?? 0) : "-" }
    }

    private var frame: String {
        let stamp = ISO8601DateFormatter()
        let sums = counts
        let rows = sums.map { id, count in
            var fields: [TextBlock.Field] = [
                .init(key: "row", value: id),
                .init(key: "title", value: count.name ?? id),
                .init(key: "detail", value: Self.detail(of: count)),
                .init(key: "runs", value: String(count.runs)),
                .init(key: "failures", value: String(count.failures.count)),
                .init(key: "cpu", value: String(format: "%.3f", count.cost.cpu)),
                .init(key: "seconds", value: String(format: "%.3f", count.seconds)),
                .init(key: "read", value: String(count.cost.read)),
                .init(key: "written", value: String(count.cost.written)),
                .init(key: "wakeups", value: String(count.cost.wakeups)),
                .init(key: "acts", value: String(count.acts))
            ]
            if let last = count.last { fields.append(.init(key: "last", value: stamp.string(from: last))) }
            fields += acts(of: id).map { .init(key: "days", value: $0) }
            fields.append(.init(key: "seen", value: String(days.count { $0.spots[id] != nil })))
            fields += (cards.first { $0.id == id }?.places ?? []).map { .init(key: "shows", value: $0) }
            fields += cards.filter { $0.places.contains(id) }.map { .init(key: "cards", value: $0.id) }
            fields += count.callers.sorted { $0.key < $1.key }.map { .init(key: "runs.by.\($0.key)", value: String($0.value)) }
            fields += ran(by: id, in: sums).map { .init(key: "ran.\($0.id)", value: String($0.runs)) }
            fields += count.reads.sorted { $0.key < $1.key }.map { .init(key: "reads.\($0.key)", value: String($0.value)) }
            if count.hidden != .zero {
                fields += [.init(key: "hidden.cpu", value: String(format: "%.3f", count.hidden.cpu)), .init(key: "hidden.wakeups", value: String(count.hidden.wakeups))]
            }
            if let middle = count.answers.time(0.5), let slow = count.answers.time(0.95) {
                fields += [.init(key: "p50", value: String(format: "%.3f", middle)), .init(key: "p95", value: String(format: "%.3f", slow))]
            }
            if count.cost.memory > 0 { fields.append(.init(key: "memory", value: String(count.cost.memory))) }
            fields += count.failures.kinds.sorted { $0.key < $1.key }.map { .init(key: "failures.\($0.key)", value: String($0.value)) }
            if let failed = count.failures.last { fields.append(.init(key: "failed", value: stamp.string(from: failed))) }
            fields += count.calls.sorted { $0.key < $1.key }.map { .init(key: "call.\($0.key)", value: String($0.value)) }
            if count.network { fields.append(.init(key: "network", value: "declared")) }
            if let view = count.view {
                fields += [.init(key: "bodies", value: String(view.bodies)), .init(key: "body", value: String(format: "%.6f", view.seconds))]
            }
            if let fault = count.fault { fields += [.init(key: "fault", value: fault), .init(key: "tone", value: "bad")] }
            return TextBlock(fields: fields).text
        }
        let uses = uses.enumerated().map { index, use in
            TextBlock(fields: [
                .init(key: "use", value: String(index + 1)),
                .init(key: "time", value: stamp.string(from: use.time)),
                .init(key: "spot", value: use.spot),
                .init(key: "call", value: use.call),
                .init(key: "declared", value: String(use.declared))
            ]).text
        }
        return (rows + uses).map { $0 + "\n" }.joined()
    }

    private var json: String {
        get throws {
            struct Shown: Encodable {
                let day: String
                let countsActs: Bool
                let spots: [String: SpotUsage.Count]
                let uses: [SpotUsage.Use]
            }
            let kept = days.map { day in
                Shown(day: day.day, countsActs: day.countsActs, spots: day.spots.filter { spot == nil || $0.key == spot }, uses: day.uses.filter { spot == nil || $0.spot == spot })
            }
            return try PrintForm.json(kept, dates: .iso8601)
        }
    }

    private static func detail(of count: SpotUsage.Count) -> String {
        var parts = ["\(time(count.cost.cpu)) CPU"]
        if count.runs > 0 { parts.append("\(count.runs) \(count.runs == 1 ? "run" : "runs") · \(time(count.seconds / Double(count.runs))) each") }
        if let view = count.view { parts.append(words(of: view, split: " · ")) }
        return parts.joined(separator: " · ")
    }

    private static func words(of view: SpotUsage.ViewTime, split: String) -> String {
        let each = view.seconds / Double(max(view.bodies, 1)) * 1000
        return "\(view.bodies) \(view.bodies == 1 ? "body" : "bodies") of its view\(split)\(String(format: "%.2f", each)) ms each"
    }

    private static func time(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.1f s", seconds)
    }
}
