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

    /// The toast of each copy of a prompt.
    public static let copied = "Copied a prompt for your agent. Paste it into Claude Code, Codex or another agent."

    /// Asks for a new spot in the plugins folder that does what the person described.
    public func building(_ description: String) -> String {
        """
        Build an Openspot spot that does this: \(description)

        Write it as one new file in \(folder.path). Its ID is the name of the file with no extension.
        \(steps(for: "<id>"))
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

    /// Asks to read a spot and tell what it does and what it runs on the person's computer, with no change.
    public func reviewing(_ file: URL) -> String {
        """
        Read the Openspot spot in \(file.path), and change nothing.
        Tell me what it does, what it runs on my computer, which files it reads or writes, and whether it uses the network.
        First run "\(app)" guide, so that you know how a spot works.
        """
    }

    /// Asks for the store listing of a spot: a readme beside it, a description, and a preview mode with fake data.
    public func listing(_ file: URL) -> String {
        let readme = SpotListing.readme(of: file).lastPathComponent
        return """
        Write the store listing of the Openspot spot in \(file.path). Do not change what it does.
        1. Write \(readme) beside it: what the spot does and how to use it, in two or three short paragraphs, then what it runs on my computer, which files it reads or writes, and whether it uses the network.
        2. Give its header a detail= line of one short sentence, if it has none.
        3. Add preview=sample to its header, and make its read print fake rows, with no data of mine, while OPENSPOT_PREVIEW is 1.
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

    /// Puts the words on the clipboard, and returns the toast that says so.
    func copy(_ text: String) async throws -> String {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["LC_ALL=en_US.UTF-8", "pbcopy"], input: text)
        return Self.copied
    }
}
