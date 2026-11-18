import Foundation

/// A coding agent that runs a session.
enum Agent: String {
    case claude
    case codex

    /// The name of its logo file, next to the spot.
    var logo: String { self == .claude ? "claude" : "openai" }
}

/// One running session of a coding agent: what it was last asked, whether it waits for you, and how full its context is.
struct Session: Equatable {
    let agent: Agent
    let id: String
    let pid: Int32
    let folder: String
    let task: String
    let waits: Bool
    let context: Double?
    let pane: String?
    var active: Date = .distantPast

    /// The last part of its folder, such as `shop`.
    var project: String { (folder as NSString).lastPathComponent }
}

/// A running agent process and the folder it works in.
struct Running: Equatable {
    let pid: Int32
    let folder: String
}

/// How much of an agent's usage limit is spent, from 0 to 1.
struct Limit: Equatable {
    let agent: Agent
    let used: Double
}

extension Limit {
    /// The highest limit that `claude -p /usage` prints, such as `Current week (all models): 41% used`.
    init?(claudeUsage text: String) {
        let used = text.split(separator: "\n").compactMap { line -> Double? in
            guard line.hasPrefix("Current "), let colon = line.firstIndex(of: ":") else { return nil }
            let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard let percent = rest.split(separator: "%").first, rest.contains("% used") else { return nil }
            return Double(percent).map { $0 / 100 }
        }.max()
        guard let used else { return nil }
        self.init(agent: .claude, used: used)
    }
}

/// Reads JSON lines, one object for each line that parses.
func objects(in url: URL) -> [[String: Any]] {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return text.split(separator: "\n").compactMap { line in
        (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
    }
}

/// Folds a prompt to one line.
func oneLine(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
}
