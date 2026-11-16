import Foundation

public struct StatsReport: Sendable {
    public enum Format: Equatable, Sendable {
        case frame, json
    }

    let days: [SpotUsage.Day]
    let spot: String?

    public init(days: [SpotUsage.Day], spot: String?) {
        self.days = days
        self.spot = spot
    }

    public func text(_ format: Format) throws -> String {
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
        return sums.sorted { ($0.value.cpu, $1.key) > ($1.value.cpu, $0.key) }.map { ($0.key, $0.value) }
    }

    private var uses: [SpotUsage.Use] {
        days.flatMap(\.uses).filter { spot == nil || $0.spot == spot }.sorted { $0.time > $1.time }
    }

    private var frame: String {
        let rows = counts.map { id, count in
            var fields: [TextBlock.Field] = [
                .init(key: "row", value: id),
                .init(key: "title", value: count.name ?? id),
                .init(key: "detail", value: Self.detail(of: count)),
                .init(key: "runs", value: String(count.runs)),
                .init(key: "failures", value: String(count.failures)),
                .init(key: "cpu", value: String(format: "%.3f", count.cpu)),
                .init(key: "seconds", value: String(format: "%.3f", count.seconds)),
                .init(key: "read", value: String(count.read)),
                .init(key: "written", value: String(count.written)),
                .init(key: "wakeups", value: String(count.wakeups))
            ]
            fields += count.calls.sorted { $0.key < $1.key }.map { .init(key: "call.\($0.key)", value: String($0.value)) }
            if count.network { fields.append(.init(key: "network", value: "declared")) }
            if let view = count.view {
                fields += [.init(key: "bodies", value: String(view.bodies)), .init(key: "body", value: String(format: "%.6f", view.seconds))]
            }
            if let fault = count.fault { fields += [.init(key: "fault", value: fault), .init(key: "tone", value: "bad")] }
            return TextBlock(fields: fields).text
        }
        let stamp = ISO8601DateFormatter()
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
                let spots: [String: SpotUsage.Count]
                let uses: [SpotUsage.Use]
            }
            let kept = days.map { day in
                Shown(day: day.day, spots: day.spots.filter { spot == nil || $0.key == spot }, uses: day.uses.filter { spot == nil || $0.spot == spot })
            }
            return try PrintForm.json(kept, dates: .iso8601)
        }
    }

    private static func detail(of count: SpotUsage.Count) -> String {
        var parts = ["\(time(count.cpu)) CPU"]
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
