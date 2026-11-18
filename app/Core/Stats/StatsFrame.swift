import Foundation

struct StatsFrame {
    let stats: Stats

    var text: String {
        let stamp = ISO8601DateFormatter()
        let rows = stats.rows.map { row in
            let (id, count) = (row.id, row.count)
            var fields: [TextBlock.Field] = [.init(key: "row", value: id)]
            if let version = row.version { fields.append(.init(key: "version", value: version)) }
            if let since = row.since { fields.append(.init(key: "since", value: stamp.string(from: since))) }
            fields += [
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
            fields += row.acts.map { .init(key: "days", value: $0) }
            fields.append(.init(key: "seen", value: String(row.seen)))
            fields += (stats.cards.first { $0.id == id }?.places ?? []).map { .init(key: "shows", value: $0) }
            fields += stats.cards.filter { $0.places.contains(id) }.map { .init(key: "cards", value: $0.id) }
            fields += count.callers.sorted { $0.key < $1.key }.map { .init(key: "runs.by.\($0.key)", value: String($0.value)) }
            fields += stats.ran(by: id).map { .init(key: "ran.\($0.id)", value: String($0.runs)) }
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
        let uses = stats.uses.enumerated().map { index, use in
            TextBlock(fields: [
                .init(key: "use", value: String(index + 1)),
                .init(key: "time", value: stamp.string(from: use.time)),
                .init(key: "spot", value: use.spot),
                .init(key: "call", value: use.call),
                .init(key: "declared", value: String(use.declared))
            ]).text
        }
        let searches = stats.searches.map { TextBlock(fields: [.init(key: "search", value: $0.text), .init(key: "count", value: String($0.count))]).text }
        return (rows + uses + searches).map { $0 + "\n" }.joined()
    }

    private static func detail(of count: StatsLog.Count) -> String {
        var parts = ["\(time(count.cost.cpu)) CPU"]
        if count.runs > 0 { parts.append("\(count.runs) \(count.runs == 1 ? "run" : "runs") · \(time(count.seconds / Double(count.runs))) each") }
        if let view = count.view { parts.append(words(of: view, split: " · ")) }
        return parts.joined(separator: " · ")
    }

    private static func words(of view: StatsLog.ViewTime, split: String) -> String {
        let each = view.seconds / Double(max(view.bodies, 1)) * 1000
        return "\(view.bodies) \(view.bodies == 1 ? "body" : "bodies") of its view\(split)\(String(format: "%.2f", each)) ms each"
    }

    static func time(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.1f s", seconds)
    }
}
