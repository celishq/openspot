import Foundation

/// How a prompt reaches a coding agent: a new Terminal window that runs the agent in the plugins folder with the prompt,
/// or the clipboard when the person chose it or no agent is found.
public struct AgentHandoff: Sendable {
    /// An agent that Openspot can start, by the name of its command.
    public enum Agent: String, CaseIterable, Sendable {
        case claude
        case codex

        public var title: String {
            switch self {
            case .claude: "Claude Code"
            case .codex: "Codex"
            }
        }
    }

    /// The choice that copies the prompt and starts no agent.
    public static let copy = "copy"

    public let prompt: AgentPrompt
    /// The folders, as a PATH, where the agents are looked for: the PATH of the person's shell.
    let searchPath: @Sendable () async -> String
    /// The folder of the small scripts that Terminal runs.
    let scripts: URL

    public init(prompt: AgentPrompt, searchPath: @escaping @Sendable () async -> String, scripts: URL = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-agent", isDirectory: true)) {
        self.prompt = prompt
        self.searchPath = searchPath
        self.scripts = scripts
    }

    /// Each agent that the search path holds, in the order of `Agent`, with the path of its command.
    public func agents() async -> [(agent: Agent, path: String)] {
        let folders = await searchPath().split(separator: ":").map(String.init)
        return Agent.allCases.compactMap { agent in
            folders.lazy.map { URL(fileURLWithPath: $0).appendingPathComponent(agent.rawValue).path }
                .first { FileManager.default.isExecutableFile(atPath: $0) }
                .map { (agent, $0) }
        }
    }

    /// Gives the text to the agent of the choice, or to the first agent found with no choice, in a new Terminal window. With
    /// `copy`, or with no agent, it copies the text. Returns the toast that says where the text went, with what the agent is
    /// `doing`, such as `building it`.
    public func hand(_ text: String, choice: String?, doing: String) async throws -> String {
        let found = await agents()
        let agent = choice == Self.copy ? nil : found.first { $0.agent.rawValue == choice } ?? found.first
        guard let agent else {
            try await prompt.copy(text)
            return "Copied a prompt for your agent. Paste it into Claude Code, Codex or another agent."
        }
        let file = try script(running: agent.path, with: text)
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["open", file.path])
        return "\(agent.agent.title) is \(doing) in Terminal."
    }

    /// A script that Terminal runs: it goes to the plugins folder, puts the `openspot` command on the PATH and starts the
    /// agent with the text.
    private func script(running agent: String, with text: String) throws -> URL {
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        let file = scripts.appendingPathComponent("\(UUID().uuidString).command")
        let helpers = URL(fileURLWithPath: prompt.app).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Helpers").path
        let body = """
        #!/bin/zsh -l
        cd \(Self.quoted(prompt.folder.path))
        export PATH=\(Self.quoted(helpers)):"$PATH"
        exec \(Self.quoted(agent)) \(Self.quoted(text))

        """
        try body.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        return file
    }

    private static func quoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

extension AgentHandoff: Equatable {
    public static func == (left: AgentHandoff, right: AgentHandoff) -> Bool {
        left.prompt == right.prompt && left.scripts == right.scripts
    }
}
