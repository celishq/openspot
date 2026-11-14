import Foundation

public struct AgentPrompt: Equatable, Sendable {
    public let folder: URL
    public let guide: URL
    public let app: String

    public init(folder: URL, guide: URL, app: String) {
        self.folder = folder
        self.guide = guide
        self.app = app
    }

    public static func command(of app: String) -> String {
        let contents = URL(fileURLWithPath: app).deletingLastPathComponent().deletingLastPathComponent()
        let client = contents.appendingPathComponent("Helpers/openspot").path
        return FileManager.default.isExecutableFile(atPath: client) ? client : app
    }

    public static let copied = "Copied a prompt for your agent. Paste it into Claude Code, Codex or another agent."

    public func building(_ description: String) -> String {
        """
        Build an Openspot spot that does this: \(description)

        Write it as a script in a new spot folder in \(folder.path), such as weather.spot/weather.sh. Its ID is the name of the folder with no extension.
        \(steps(for: "<id>"))
        """
    }

    public func fixing(_ file: URL, faults: [String]) -> String {
        """
        Fix the Openspot spot in \(file.path). Openspot does not load it, and says:
        \(faults.joined(separator: "\n"))

        \(steps(for: SpotID(file: file).description))
        """
    }

    public func changing(_ file: URL, failure: String?) -> String {
        let failed = failure.map { "Its last call failed, and said: \($0)\n" } ?? ""
        return """
        Change the Openspot spot in \(file.path). Ask me what to change before you change it.
        \(failed)
        \(steps(for: SpotID(file: file).description))
        """
    }

    private func steps(for id: String) -> String {
        """
        First run "\(app)" guide, and read all of it.
        Try each call with "\(app)" spot run \(id) [call] [value]..., and look at its card with "\(app)" render --spot \(id) --card wide card.png.
        When it is ready, run "\(app)" check --json "\(folder.path)" and fix each fault until it prints [].
        At the end of your answer, run "\(app)" spot show \(id), and tell me what the spot runs on my computer.

        """
    }

    func copy(_ text: String) async throws -> String {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["LC_ALL=en_US.UTF-8", "pbcopy"], input: text)
        return Self.copied
    }
}
