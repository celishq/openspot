import Foundation

/// What `openspot spot stats` prints from the days of the counts (Z10, Z11): their sum for a person, a `row` block for each
/// spot with the most CPU time first and a `power` block for each use of a power, the newest first, or the days as JSON.
public struct StatsReport: Sendable {
    public enum Format: Equatable, Sendable {
        case text, frame, json
    }

    let days: [SpotUsage.Day]
    /// The one spot to keep, or nil for each spot.
    let spot: String?

    public init(days: [SpotUsage.Day], spot: String?) {
        self.days = days
        self.spot = spot
    }

    public func text(_ format: Format) throws -> String {
        switch format {
        case .text: words
        case .frame: frame
        case .json: try json
        }
    }

    /// The count of each spot over the days, the most CPU time first.
    private var counts: [(id: String, count: SpotUsage.Count)] {
        var sums: [String: SpotUsage.Count] = [:]
        for day in days {
            for (id, count) in day.spots where spot == nil || spot == id {
                sums[id] = sums[id].map { $0.adding(count) } ?? count
            }
        }
        return sums.sorted { ($0.value.cpu, $1.key) > ($1.value.cpu, $0.key) }.map { ($0.key, $0.value) }
    }

    /// Each use of a power over the days, the newest first.
    private var powers: [SpotUsage.Power] {
        days.flatMap(\.powers).filter { spot == nil || $0.spot == spot }.sorted { $0.time > $1.time }
    }

    private var words: String {
        let counts = counts
        guard !counts.isEmpty else { return "Openspot has counted no run on these days.\n" }
        let head = days.count == 1 ? "Today" : "The last \(days.count) days"
        var lines = [head]
        for (id, count) in counts {
            var parts = ["\(count.runs) \(count.runs == 1 ? "run" : "runs")"]
            if count.failures > 0 { parts.append("\(count.failures) failed") }
            parts += ["\(Self.time(count.cpu)) CPU", "\(Self.bytes(count.read)) read", "\(Self.bytes(count.written)) written", "\(count.wakeups) wakeups"]
            parts += count.uses.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
            if count.network { parts.append("network declared") }
            lines.append("\(count.name ?? id): \(parts.joined(separator: " · "))")
            if let fault = count.fault { lines.append("  Last fault: \(fault.replacingOccurrences(of: "\n", with: " "))") }
        }
        let powers = powers
        if !powers.isEmpty {
            let names = Dictionary(counts.map { ($0.id, $0.count.name ?? $0.id) }) { first, _ in first }
            let clock = DateFormatter()
            clock.dateFormat = days.count == 1 ? "HH:mm" : "yyyy-MM-dd HH:mm"
            lines += ["", "Uses of a power"]
            lines += powers.map { "\(clock.string(from: $0.time)) \(names[$0.spot] ?? $0.spot) \($0.call)\($0.declared ? "" : ", not in its uses")" }
        }
        return lines.joined(separator: "\n") + "\n"
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
            fields += count.uses.sorted { $0.key < $1.key }.map { .init(key: "use.\($0.key)", value: String($0.value)) }
            if count.network { fields.append(.init(key: "network", value: "declared")) }
            if let fault = count.fault { fields += [.init(key: "fault", value: fault), .init(key: "tone", value: "bad")] }
            return TextBlock(fields: fields).text
        }
        let stamp = ISO8601DateFormatter()
        let powers = powers.enumerated().map { index, power in
            TextBlock(fields: [
                .init(key: "power", value: String(index + 1)),
                .init(key: "time", value: stamp.string(from: power.time)),
                .init(key: "spot", value: power.spot),
                .init(key: "call", value: power.call),
                .init(key: "declared", value: String(power.declared))
            ]).text
        }
        return (rows + powers).map { $0 + "\n" }.joined()
    }

    private var json: String {
        get throws {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            struct Shown: Encodable {
                let day: String
                let spots: [String: SpotUsage.Count]
                let powers: [SpotUsage.Power]
            }
            let kept = days.map { day in
                Shown(day: day.day, spots: day.spots.filter { spot == nil || $0.key == spot }, powers: day.powers.filter { spot == nil || $0.spot == spot })
            }
            return String(decoding: try encoder.encode(kept), as: UTF8.self) + "\n"
        }
    }

    /// Its CPU time, its runs and the time of each run on average, in words.
    private static func detail(of count: SpotUsage.Count) -> String {
        let cpu = "\(time(count.cpu)) CPU"
        guard count.runs > 0 else { return cpu }
        return "\(cpu) · \(count.runs) \(count.runs == 1 ? "run" : "runs") · \(time(count.seconds / Double(count.runs))) each"
    }

    private static func time(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.1f s", seconds)
    }

    private static func bytes(_ count: UInt64) -> String {
        count < 1024 ? "\(count) B" : count < 1_048_576 ? String(format: "%.1f KB", Double(count) / 1024) : String(format: "%.1f MB", Double(count) / 1_048_576)
    }
}
