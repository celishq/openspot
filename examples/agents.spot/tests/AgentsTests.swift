import XCTest

final class AgentsTests: XCTestCase {
    func testAClaudeSessionShowsItsLastPromptItsStateAndItsContext() throws {
        let root = try emptyFolder()
        try write(root, "sessions/41.json", #"{"pid":41,"sessionId":"s1","cwd":"/Users/me/Code/shop","status":"busy","tmux":"0:@2.%7"}"#)
        try write(root, "projects/-Users-me-Code-shop/s1.jsonl", [
            #"{"type":"user","origin":{"kind":"human"},"message":{"role":"user","content":"Add a cart page"}}"#,
            #"{"type":"assistant","message":{"model":"claude-opus-5-5","usage":{"input_tokens":2,"cache_read_input_tokens":40000,"cache_creation_input_tokens":8000}}}"#,
            #"{"type":"user","origin":{"kind":"human"},"message":{"role":"user","content":[{"type":"text","text":"Now fix the\nflaky test"}]}}"#,
            #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}"#,
            #"{"type":"user","isMeta":true,"message":{"role":"user","content":"<system-reminder>x</system-reminder>"}}"#,
            #"{"type":"assistant","message":{"model":"claude-opus-5-5","usage":{"input_tokens":10,"cache_read_input_tokens":90000,"cache_creation_input_tokens":9990}}}"#,
        ].joined(separator: "\n"))

        let sessions = ClaudeFolder(url: root).sessions { $0 == 41 }

        XCTAssertEqual(sessions, [Session(agent: .claude, id: "s1", pid: 41, folder: "/Users/me/Code/shop", task: "Now fix the flaky test",
                                          waits: false, context: 0.5, pane: "%7")])
    }

    func testAnIdleClaudeSessionWaitsAndAGoneOneIsLeftOut() throws {
        let root = try emptyFolder()
        try write(root, "sessions/41.json", #"{"pid":41,"sessionId":"s1","cwd":"/a","status":"idle"}"#)
        try write(root, "sessions/42.json", #"{"pid":42,"sessionId":"s2","cwd":"/b","status":"busy"}"#)

        let sessions = ClaudeFolder(url: root).sessions { $0 == 41 }

        XCTAssertEqual(sessions.map(\.id), ["s1"])
        XCTAssertEqual(sessions.first?.waits, true)
        XCTAssertEqual(sessions.first?.task, "")
    }

    func testAClaudeContextOverTheSmallWindowCountsAgainstTheLargeOne() throws {
        let root = try emptyFolder()
        try write(root, "sessions/41.json", #"{"pid":41,"sessionId":"s1","cwd":"/a","status":"busy"}"#)
        try write(root, "projects/-a/s1.jsonl", #"{"type":"assistant","message":{"usage":{"input_tokens":0,"cache_read_input_tokens":250000,"cache_creation_input_tokens":0}}}"#)

        XCTAssertEqual(ClaudeFolder(url: root).sessions { _ in true }.first?.context, 0.25)
    }

    func testACodexSessionIsTheNewestRolloutInTheFolderOfARunningCodex() throws {
        let root = try emptyFolder()
        try write(root, "sessions/2026/11/17/rollout-old.jsonl", [
            meta("old", "/Users/me/Code/site"),
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Old ask"}]}}"#,
        ].joined(separator: "\n"))
        try age(root.appendingPathComponent("sessions/2026/11/17/rollout-old.jsonl"), by: 600)
        try write(root, "sessions/2026/11/18/rollout-new.jsonl", [
            meta("new", "/Users/me/Code/site"),
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>x</environment_context>"}]}}"#,
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Add a pricing page"}]}}"#,
            #"{"type":"event_msg","payload":{"type":"task_started"}}"#,
            tokens(used: 63, input: 95000, window: 380000),
        ].joined(separator: "\n"))

        let sessions = CodexFolder(url: root).sessions(running: [Running(pid: 7, folder: "/Users/me/Code/site")])

        XCTAssertEqual(sessions, [Session(agent: .codex, id: "new", pid: 7, folder: "/Users/me/Code/site", task: "Add a pricing page",
                                          waits: false, context: 0.25, pane: nil, active: sessions.first?.active ?? .distantPast)])
    }

    func testACodexSessionWaitsOnceItsTaskIsComplete() throws {
        let root = try emptyFolder()
        try write(root, "sessions/2026/11/18/rollout-a.jsonl", [
            meta("a", "/a"),
            #"{"type":"event_msg","payload":{"type":"task_started"}}"#,
            #"{"type":"event_msg","payload":{"type":"task_complete"}}"#,
        ].joined(separator: "\n"))

        XCTAssertEqual(CodexFolder(url: root).sessions(running: [Running(pid: 7, folder: "/a")]).first?.waits, true)
        XCTAssertEqual(CodexFolder(url: root).sessions(running: [Running(pid: 7, folder: "/elsewhere")]), [])
    }

    func testTheCodexLimitIsTheHigherWindowOfTheNewestRollout() throws {
        let root = try emptyFolder()
        try write(root, "sessions/2026/11/18/rollout-a.jsonl", [
            meta("a", "/a"),
            tokens(used: 12, input: 1, window: 10),
            #"{"type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"primary":{"used_percent":20.0,"window_minutes":300},"secondary":{"used_percent":63.0,"window_minutes":10080}}}}"#,
        ].joined(separator: "\n"))

        XCTAssertEqual(CodexFolder(url: root).limit(), Limit(agent: .codex, used: 0.63))
    }

    func testTheClaudeLimitIsTheHighestLineOfItsUsage() {
        let text = """
            You are currently using your subscription to power your Claude Code usage

            Current session: 23% used · resets 3pm (Europe/Madrid)
            Current week (all models): 41% used · resets Nov 24 at 5am (Europe/Madrid)
            Current week (Fable): 0% used · resets Nov 24 at 5am (Europe/Madrid)

            Last 24h · 4207 requests · 25 sessions
              69%  Start fresh when you switch tasks
            """

        XCTAssertEqual(Limit(claudeUsage: text), Limit(agent: .claude, used: 0.41))
        XCTAssertNil(Limit(claudeUsage: "Not logged in"))
    }

    func testAnAliasGivesItsConfigFolder() {
        XCTAssertEqual(Command(text: "claude-personal").folder(alias: "claude-personal='CLAUDE_CONFIG_DIR=~/.claude-personal claude'",
                                                               variable: "CLAUDE_CONFIG_DIR", home: "/Users/me"), "/Users/me/.claude-personal")
        XCTAssertEqual(Command(text: "codex").folder(alias: "", variable: "CODEX_HOME", home: "/Users/me"), nil)
    }

    func testTheBoardPutsTheSessionsThatWaitFirstAndListsEachAsAnItem() {
        let sessions = [
            Session(agent: .claude, id: "s1", pid: 41, folder: "/Users/me/Code/shop", task: "Add a cart page", waits: false, context: 0.5, pane: nil),
            Session(agent: .codex, id: "c1", pid: 7, folder: "/Users/me/Code/site", task: "Fix a flaky test", waits: true, context: 0.25, pane: nil),
        ]

        let frame = Board(sessions: sessions, limits: [Limit(agent: .claude, used: 0.62)], logos: URL(fileURLWithPath: "/logos")).frame

        XCTAssertTrue(frame.hasPrefix("frame=\ngrid=items\ngrid.small=card\n\nview=card\nlimit1=claude|0.62|working\ntask1=waiting|Fix a flaky test|openai|site\ntask2=working|Add a cart page|claude|shop\n\nrepeat=items\n\n"), frame)
        XCTAssertTrue(frame.contains("text=codex/7\ntitle=Fix a flaky test\ndetail=site · waits for you · 25% context\nicon=/logos/openai.png\n"), frame)
        XCTAssertTrue(frame.contains("text=claude/41\ntitle=Add a cart page\ndetail=shop · working · 50% context\nicon=/logos/claude.png\n"), frame)
    }

    func testTheBoardOrdersTheLimitsAndTheWorkingSessionsByTheirLastActivity() {
        let sessions = [
            Session(agent: .claude, id: "s1", pid: 41, folder: "/a", task: "Old", waits: false, context: nil, pane: nil, active: Date(timeIntervalSince1970: 100)),
            Session(agent: .codex, id: "c1", pid: 7, folder: "/b", task: "New", waits: false, context: nil, pane: nil, active: Date(timeIntervalSince1970: 300)),
            Session(agent: .claude, id: "s2", pid: 42, folder: "/c", task: "Waits", waits: true, context: nil, pane: nil, active: Date(timeIntervalSince1970: 50)),
        ]

        let frame = Board(sessions: sessions, limits: [Limit(agent: .claude, used: 0.1), Limit(agent: .codex, used: 0.2)], logos: URL(fileURLWithPath: "/l")).frame

        XCTAssertTrue(frame.contains("limit1=openai|0.2|working\nlimit2=claude|0.1|waiting\ntask1=waiting|Waits|claude|c\ntask2=working|New|openai|b\ntask3=working|Old|claude|a\n"), frame)
    }

    func testAClaudeSessionIsActiveWhenItsStatusLastChanged() throws {
        let root = try emptyFolder()
        try write(root, "sessions/41.json", #"{"pid":41,"sessionId":"s1","cwd":"/a","status":"busy","updatedAt":1795022025890}"#)

        XCTAssertEqual(ClaudeFolder(url: root).sessions { _ in true }.first?.active, Date(timeIntervalSince1970: 1795022025.89))
    }

    private func meta(_ id: String, _ folder: String) -> String {
        #"{"type":"session_meta","payload":{"id":"\#(id)","cwd":"\#(folder)"}}"#
    }

    private func tokens(used: Double, input: Int, window: Int) -> String {
        #"{"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":\#(input)},"model_context_window":\#(window)},"rate_limits":{"primary":{"used_percent":\#(used),"window_minutes":10080},"secondary":null}}}"#
    }

    private func write(_ root: URL, _ path: String, _ text: String) throws {
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }
}
