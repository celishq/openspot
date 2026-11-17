import Foundation

struct StatsMetrics {
    private struct Family {
        let name: String
        let type: String
        var samples: [String] = []
    }

    let rows: [StatsReport.Row]
    let uses: [SpotUsage.Use]
    let searches: [(text: String, count: Int)]

    var text: String {
        var families = [
            family("openspot_spot_acts", { [([], $0.acts)] }),
            family("openspot_spot_runs", { [([], $0.runs)] }),
            family("openspot_spot_failures", { $0.failures.kinds.sorted { $0.key < $1.key }.map { ([("kind", $0.key)], $0.value) } }),
            family("openspot_spot_call_seconds", { [([], $0.seconds)] }),
            family("process_cpu_time_seconds", { [([("hidden", "false")], max($0.cost.cpu - $0.hidden.cpu, 0)), ([("hidden", "true")], $0.hidden.cpu)] }),
            family("openspot_spot_wakeups", { [([("hidden", "false")], $0.cost.wakeups &- min($0.hidden.wakeups, $0.cost.wakeups)), ([("hidden", "true")], $0.hidden.wakeups)] }),
            family("process_disk_io_bytes", { [([("direction", "read")], $0.cost.read), ([("direction", "write")], $0.cost.written)] }),
            family("openspot_spot_memory_peak_bytes", type: "gauge", { [([], $0.cost.memory)] }),
            answers,
            family("openspot_spot_reads", { $0.reads.sorted { $0.key < $1.key }.map { ([("reason", $0.key)], $0.value) } }),
            family("openspot_spot_calls", { $0.calls.sorted { $0.key < $1.key }.map { ([("call", $0.key)], $0.value) } }),
            family("openspot_spot_started", { $0.callers.sorted { $0.key < $1.key }.map { ([("caller", $0.key)], $0.value) } }),
            family("openspot_spot_view_bodies", { [([], $0.view?.bodies ?? 0)] }),
            family("openspot_spot_view_body_seconds", { [([], $0.view?.seconds ?? 0)] })
        ]
        families.append(undeclared)
        families.append(Family(name: "openspot_search_empty", type: "counter", samples: searches.map { "openspot_search_empty_total\(Self.labelText([("query", $0.text)])) \($0.count)" }))
        return families.filter { !$0.samples.isEmpty }.map { family in
            (["# TYPE \(family.name) \(family.type)"] + family.samples).joined(separator: "\n") + "\n"
        }.joined() + "# EOF\n"
    }

    private var answers: Family {
        var family = Family(name: "openspot_spot_answer_seconds", type: "histogram")
        for row in rows where row.count.answers.total > 0 {
            var seen = 0
            for (index, count) in row.count.answers.counts.enumerated() {
                seen += count
                let bound = index < SpotUsage.AnswerTimes.bounds.count ? Self.number(SpotUsage.AnswerTimes.bounds[index]) : "+Inf"
                family.samples.append("\(family.name)_bucket\(labels(of: row, [("le", bound)])) \(seen)")
            }
        }
        return family
    }

    private var undeclared: Family {
        var counts: [String: [String: Int]] = [:]
        for use in uses where !use.declared { counts[use.spot, default: [:]][use.call, default: 0] += 1 }
        var family = Family(name: "openspot_spot_undeclared_calls", type: "counter")
        for (spot, calls) in counts.sorted(by: { $0.key < $1.key }) {
            for (call, count) in calls.sorted(by: { $0.key < $1.key }) {
                family.samples.append("\(family.name)_total\(Self.labelText([("spot", spot), ("call", call)])) \(count)")
            }
        }
        return family
    }

    private func family<Value: Numeric & Comparable & CVarArg>(_ name: String, type: String = "counter", _ values: (SpotUsage.Count) -> [([(String, String)], Value)]) -> Family {
        var family = Family(name: name, type: type)
        let sample = type == "counter" ? "\(name)_total" : name
        for row in rows {
            for (extra, value) in values(row.count) where value > 0 {
                family.samples.append("\(sample)\(labels(of: row, extra)) \(Self.number(value))")
            }
        }
        return family
    }

    private func labels(of row: StatsReport.Row, _ extra: [(String, String)]) -> String {
        Self.labelText([("spot", row.id)] + (row.version.map { [("version", $0)] } ?? []) + extra)
    }

    private static func labelText(_ pairs: [(String, String)]) -> String {
        "{" + pairs.map { "\($0.0)=\"\(escaped($0.1))\"" }.joined(separator: ",") + "}"
    }

    private static func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func number<Value: CVarArg>(_ value: Value) -> String {
        if let double = value as? Double { return String(format: "%.6g", double) }
        return "\(value)"
    }
}
