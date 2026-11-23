import Foundation

/// The home folder of Codex, such as `~/.codex`, which keeps a rollout file for each session, by day.
struct CodexFolder {
    let url: URL

    /// For each running Codex, the newest session started in its folder.
    func sessions(running: [Running]) -> [Session] {
        let rollouts = recent()
        return running.compactMap { process in
            for file in rollouts {
                let lines = objects(in: file)
                guard let meta = lines.first(where: { $0["type"] as? String == "session_meta" })?["payload"] as? [String: Any],
                      meta["cwd"] as? String == process.folder else { continue }
                var found = session(lines, id: meta["id"] as? String ?? file.lastPathComponent, process: process)
                found.active = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return found
            }
            return nil
        }
    }

    /// The higher of the two windows of the newest rate limits that Codex wrote.
    func limit() -> Limit? {
        for file in recent() {
            for line in objects(in: file).reversed() {
                guard let payload = line["payload"] as? [String: Any], payload["type"] as? String == "token_count",
                      let limits = payload["rate_limits"] as? [String: Any] else { continue }
                let used = ["primary", "secondary"].compactMap { ((limits[$0] as? [String: Any])?["used_percent"] as? NSNumber)?.doubleValue }.max()
                if let used { return Limit(agent: .codex, used: used / 100) }
            }
        }
        return nil
    }

    private func session(_ lines: [[String: Any]], id: String, process: Running) -> Session {
        var task = ""
        var waits = false
        var context: Double?
        for line in lines {
            guard let payload = line["payload"] as? [String: Any] else { continue }
            switch payload["type"] as? String {
            case "message" where payload["role"] as? String == "user":
                let texts = (payload["content"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }
                if let text = texts.first(where: { !$0.hasPrefix("<") }) { task = oneLine(text) }
            case "task_started": waits = false
            case "task_complete": waits = true
            case "token_count":
                if let info = payload["info"] as? [String: Any],
                   let input = ((info["last_token_usage"] as? [String: Any])?["input_tokens"] as? NSNumber)?.doubleValue,
                   let window = (info["model_context_window"] as? NSNumber)?.doubleValue, window > 0 {
                    context = input / window
                }
            default: break
            }
        }
        return Session(agent: .codex, id: id, pid: process.pid, folder: process.folder, task: task, waits: waits, context: context, pane: nil)
    }

    /// The rollout files of the last two days, newest first.
    private func recent() -> [URL] {
        let days = url.appendingPathComponent("sessions")
        guard let walk = FileManager.default.enumerator(at: days, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        let floor = Date().addingTimeInterval(-2 * 86_400)
        let files = walk.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }.compactMap { file -> (URL, Date)? in
            guard let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, date > floor else { return nil }
            return (file, date)
        }
        return files.sorted { $0.1 > $1.1 }.map(\.0)
    }
}
