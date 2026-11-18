import Foundation

/// What the spot prints: the card's view, with each limit and the first six sessions, and an item for every session. The
/// sessions that wait for you come first, then the most recently active; the limits follow the agent last active.
struct Board {
    let sessions: [Session]
    let limits: [Limit]
    let logos: URL

    var frame: String {
        let ordered = sessions.sorted { ($0.waits ? 0 : 1, -$0.active.timeIntervalSince1970) < ($1.waits ? 0 : 1, -$1.active.timeIntervalSince1970) }
        let latest = { (agent: Agent) in sessions.filter { $0.agent == agent }.map(\.active).max() ?? .distantPast }
        var card = ["view=card"]
        for (index, limit) in limits.sorted(by: { latest($0.agent) > latest($1.agent) }).enumerated() {
            let waits = sessions.contains { $0.agent == limit.agent && $0.waits }
            card.append("limit\(index + 1)=\(limit.agent.logo)|\(limit.used)|\(waits ? "waiting" : "working")")
        }
        for (index, session) in ordered.prefix(6).enumerated() {
            card.append("task\(index + 1)=\(session.waits ? "waiting" : "working")|\(clean(title(session)))|\(session.agent.logo)|\(clean(session.project))")
        }
        var blocks = ["frame=\ngrid=items\ngrid.small=card", card.joined(separator: "\n"), "repeat=items"]
        for session in ordered {
            var detail = [session.project, session.waits ? "waits for you" : "working"]
            if let context = session.context { detail.append("\(Int((context * 100).rounded()))% context") }
            blocks.append("""
                text=\(session.agent.rawValue)/\(session.pid)
                title=\(clean(title(session)))
                detail=\(clean(detail.joined(separator: " · ")))
                icon=\(logos.appendingPathComponent("\(session.agent.logo).png").path)
                """)
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }

    private func title(_ session: Session) -> String {
        session.task.isEmpty ? "New session" : session.task
    }

    private func clean(_ text: String) -> String {
        oneLine(text).replacingOccurrences(of: "|", with: "/")
    }
}
