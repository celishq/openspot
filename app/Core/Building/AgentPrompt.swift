import Foundation

/// The words that ask a coding agent to build or fix a spot, with the places that it needs: the plugins folder and the
/// `openspot` command of this app.
public struct AgentPrompt: Equatable, Sendable {
    public let folder: URL
    public let guide: URL
    /// The program of this app, which is the `openspot` command.
    public let app: String

    public init(folder: URL, guide: URL, app: String) {
        self.folder = folder
        self.guide = guide
        self.app = app
    }

    /// Asks for a new spot that does what the person described, in the placeholder file that Openspot made for it.
    public func building(_ description: String, in file: URL) -> String {
        let id = file.deletingPathExtension().lastPathComponent
        return """
        Build an Openspot spot that does this: \(description)

        Openspot made a placeholder for it at \(file.path), with the ID \(id). Write the spot in that file. When a better name fits, rename the file, and the ID changes with it.
        \(steps(for: id))
        """
    }

    /// Asks to fix the file of a spot that does not load, with each fault that Openspot found.
    public func fixing(_ file: URL, faults: [String]) -> String {
        """
        Fix the Openspot spot in \(file.path). Openspot does not load it, and says:
        \(faults.joined(separator: "\n"))

        \(steps(for: file.deletingPathExtension().lastPathComponent))
        """
    }

    /// Asks to change a spot, after the agent asks the person what to change, with the words of its last failed call.
    public func changing(_ file: URL, failure: String?) -> String {
        let failed = failure.map { "Its last call failed, and said: \($0)\n" } ?? ""
        return """
        Change the Openspot spot in \(file.path). Ask me what to change before you change it.
        \(failed)
        \(steps(for: file.deletingPathExtension().lastPathComponent))
        """
    }

    /// The steps of each build: the guide, a try, a look, the check and a show.
    private func steps(for id: String) -> String {
        """
        First run "\(app)" guide, and read all of it.
        Try each call with "\(app)" spot run \(id) [call] [value]..., and look at its card with "\(app)" render --spot \(id) --card wide card.png.
        When it is ready, run "\(app)" check --json "\(folder.path)" and fix each fault until it prints [].
        At the end of your answer, run "\(app)" spot show \(id), and tell me what the spot runs on my computer.

        """
    }

    /// Puts the words on the clipboard.
    func copy(_ text: String) async throws {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["LC_ALL=en_US.UTF-8", "pbcopy"], input: text)
    }
}
