import Foundation

/// The words that ask a coding agent to build or fix a spot, with the places that it needs: the plugins folder, the guide
/// and the `openspot` command of this app.
public struct AgentPrompt: Equatable, Sendable {
    public let folder: URL
    public let guide: URL
    public let app: String

    public init(folder: URL, guide: URL, app: String) {
        self.folder = folder
        self.guide = guide
        self.app = app
    }

    /// Asks for a new spot that does what the person described.
    public func building(_ description: String) -> String {
        """
        Build an Openspot plugin that does this: \(description)

        Read the guide first: \(guide.path)
        Put the plugin in: \(folder.path)
        To write a sheet of parts, read the language first: "\(app)" catalog
        To see a sheet, run: "\(app)" check --sheet < sheet.txt, and "\(app)" render sheet.png < sheet.txt
        When it is ready, run this and fix each fault it reports: "\(app)" check "\(folder.path)"
        Tell me what the plugin runs on my computer.

        """
    }

    /// Asks to fix the file of a spot that does not load, with each fault that Openspot found.
    public func fixing(_ file: URL, faults: [String]) -> String {
        """
        Fix the Openspot plugin in \(file.path). Openspot does not load it, and says:
        \(faults.joined(separator: "\n"))

        Read the guide first: \(guide.path)
        When it is fixed, run this and fix each fault it reports: "\(app)" check "\(folder.path)"
        Tell me what you changed.

        """
    }

    /// Puts the words on the clipboard.
    func copy(_ text: String) async throws {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["LC_ALL=en_US.UTF-8", "pbcopy"], input: text)
    }
}
