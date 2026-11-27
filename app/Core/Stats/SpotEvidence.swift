import Foundation

public struct SpotEvidence: Equatable, Sendable {
    public static let days = 14

    public let id: String
    public let facts: [String]
    public let goal: String?
    let app: String

    public init?(of id: String, in days: [StatsLog.Day], app: String) {
        let all = Stats(days: days, spot: nil).rows
        guard let row = all.first(where: { $0.id == id }) else { return nil }
        let (count, undeclared) = (row.count, row.undeclared)
        let seen = Double(max(row.seen, 1))
        var facts = [Self.calls(of: count)]
        if count.cost.cpu > 0 {
            let share = count.cost.cpu / max(all.reduce(0) { $0 + $1.count.cost.cpu }, .ulpOfOne)
            let perAct = count.acts > 0 ? ", \(StatsFrame.time(count.cost.cpu / Double(count.acts))) for each act" : ""
            facts.append("CPU: \(StatsFrame.time(count.cost.cpu / seen)) a day, \(Int((share * 100).rounded()))% of the CPU of all spots\(perAct).")
        }
        if count.hidden != .zero {
            facts.append("While the panel was hidden: \(StatsFrame.time(count.hidden.cpu / seen)) CPU and \(Int((Double(count.hidden.wakeups) / seen).rounded())) wakeups a day.")
        }
        let acts = all.reduce(0) { $0 + $1.count.acts }
        facts.append(count.acts == 0 ? "Acts: none." : String(format: "Acts: %.1f a day, %d%% of the acts of all spots.", Double(count.acts) / seen, Int((Double(count.acts) / Double(acts) * 100).rounded())))
        if let middle = count.answers.time(0.5), let slow = count.answers.time(0.95) {
            facts.append("95 in 100 of its reads and searches first answered within \(StatsFrame.time(slow)), half within \(StatsFrame.time(middle)).")
        }
        if count.cost.memory > 0 { facts.append("Its own process held at most \(count.cost.memory / 1_048_576) MB.") }
        if !undeclared.isEmpty {
            facts.append("Calls that its spot.toml does not declare: " + undeclared.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value) \($0.value == 1 ? "time" : "times")" }.joined(separator: ", ") + ".")
        }
        let versions = Stats(days: days, spot: id, byVersion: true).rows
        if let last = versions.last, versions.count > 1 {
            let before = versions.dropLast().reduce(StatsLog.Count()) { $0.adding($1.count) }
            facts.append("Since its last change: \(last.count.failures.count) of \(last.count.runs) calls failed. Before it: \(before.failures.count) of \(before.runs) failed.")
        }
        var goals: [String] = []
        if count.failures.count > 0 { goals.append("Make every call pass, and keep what works.") }
        if !undeclared.isEmpty { goals.append("Declare each use in its spot.toml, or remove the call that needs it.") }
        self.id = id
        self.facts = facts
        self.app = app
        goal = goals.isEmpty ? nil : goals.joined(separator: " ")
    }

    static func read(of id: String, runs: SpotRuns?, stats: URL, app: String) async -> SpotEvidence? {
        SpotEvidence(of: id, in: await StatsLog.days(days, runs: runs, stats: stats), app: app)
    }

    var text: String {
        """
        What Openspot counted of this spot over the last \(Self.days) days on this Mac:
        \(facts.map { "- \($0)" }.joined(separator: "\n"))
        Run \(AgentPrompt.quoted(app)) spot stats --days \(Self.days) --spot \(id) --by version for every count.
        """
    }

    private static func calls(of count: StatsLog.Count) -> String {
        let kinds = count.failures.kinds.sorted { $0.key < $1.key }.map { "\($0.value) \(StatsLog.Failure(rawValue: $0.key)?.words ?? $0.key)" }.joined(separator: ", ")
        var line = "\(count.runs) \(count.runs == 1 ? "call" : "calls"), \(count.failures.count) failed\(kinds.isEmpty ? "" : ": \(kinds)")."
        if let fault = count.fault { line += " The last fault: \(fault)" }
        return line
    }
}
