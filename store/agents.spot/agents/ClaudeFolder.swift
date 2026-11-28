import Foundation

/// The config folder of Claude Code, such as `~/.claude`: a file for each running session, and a transcript for each.
struct ClaudeFolder {
    let url: URL

    /// The sessions whose process still runs, with the last prompt and the context of each.
    func sessions(alive: (Int32) -> Bool) -> [Session] {
        let folder = url.appendingPathComponent("sessions")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap { file -> Session? in
            guard let data = try? Data(contentsOf: file),
                  let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let pid = (info["pid"] as? NSNumber)?.int32Value, alive(pid),
                  let id = info["sessionId"] as? String, let cwd = info["cwd"] as? String else { return nil }
            let (task, context) = transcript(id: id, cwd: cwd)
            let pane = (info["tmux"] as? String)?.split(separator: ".").last.map(String.init)
            return Session(agent: .claude, id: id, pid: pid, folder: cwd, task: task, waits: info["status"] as? String == "idle",
                           context: context, pane: pane,
                           active: ((info["updatedAt"] as? NSNumber)?.doubleValue).map { Date(timeIntervalSince1970: $0 / 1000) } ?? .distantPast)
        }.sorted { $0.pid < $1.pid }
    }

    /// The last prompt a person typed, and how full the context was at the last answer.
    private func transcript(id: String, cwd: String) -> (String, Double?) {
        let project = cwd.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let file = url.appendingPathComponent("projects/\(String(project))/\(id).jsonl")
        var task = ""
        var tokens: Double?
        for line in objects(in: file) {
            let message = line["message"] as? [String: Any]
            if line["type"] as? String == "user", (line["origin"] as? [String: Any])?["kind"] as? String == "human" {
                if let text = message?["content"] as? String {
                    task = oneLine(text)
                } else if let parts = message?["content"] as? [[String: Any]], let text = parts.first(where: { $0["type"] as? String == "text" })?["text"] as? String {
                    task = oneLine(text)
                }
            }
            if line["type"] as? String == "assistant", let usage = message?["usage"] as? [String: Any] {
                tokens = ["input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"]
                    .reduce(0) { $0 + ((usage[$1] as? NSNumber)?.doubleValue ?? 0) }
            }
        }
        return (task, tokens.map { $0 / ($0 > 200_000 ? 1_000_000 : 200_000) })
    }
}
