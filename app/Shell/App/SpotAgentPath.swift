import Foundation
import OpenspotCore

/// The folders where the person's shell finds commands, where the New spot sheet looks for coding agents. An app that
/// starts from the Dock has a short PATH, so this asks the person's login shell once and keeps its answer.
enum SpotAgentPath {
    private static let limit: TimeInterval = 5
    private static let kept = KeptPath()

    /// The PATH of the person's login shell, with the folders where agents install themselves.
    static let lookup: @Sendable () async -> String = {
        if let path = await kept.path { return path }
        let shell = ProcessInfo.processInfo.environment["SHELL"].flatMap { $0.isEmpty ? nil : $0 } ?? "/bin/zsh"
        let text = (try? await ScriptProcess.output(url: URL(fileURLWithPath: shell), arguments: ["-lic", "printf '\\n%s' \"$PATH\""], limit: limit)) ?? ""
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let found = text.split(separator: "\n").last.map(String.init) ?? ""
        let path = [found, "\(home)/.local/bin", "\(home)/.claude/local", "/opt/homebrew/bin", "/usr/local/bin"].joined(separator: ":")
        await kept.keep(path)
        return path
    }
}

/// The PATH that one lookup found, which later lookups reuse.
private actor KeptPath {
    var path: String?

    func keep(_ path: String) {
        self.path = path
    }
}
