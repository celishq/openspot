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

    public static let copied = "Prompt copied. Paste it into your agent."

    static let finishAlone = "Don't ask me anything. Choose a short name and sensible defaults yourself, build it to the end, and leave it ready to use in Openspot."

    public func building(_ description: String) -> String {
        """
        Build an Openspot spot that does this: \(description)
        \(Self.finishAlone)

        \(writing)
        \(steps(for: "<id>"))
        """
    }

    public func interviewing() -> String {
        """
        Help me build an Openspot spot. Start by asking me what the spot should do: a few short, plain questions, one at a time, and wait for each answer. Then build it.

        \(writing)
        \(steps(for: "<id>"))
        """
    }

    private var writing: String {
        "Write it as a script in a new spot folder in \(folder.path), such as weather.spot/weather.sh. Its ID is the name of the folder with no extension."
    }

    public func fixing(_ file: URL, faults: [String]) -> String {
        """
        Fix the Openspot spot in \(file.path). Openspot does not load it, and says:
        \(faults.joined(separator: "\n"))

        \(steps(for: SpotID(file: file).description))
        """
    }

    static let finishChange = "Don't ask me anything. Make the change to the end, keep what already works, and leave the spot ready to use in Openspot."

    public func changing(_ file: URL, wish: String, evidence: SpotEvidence? = nil) -> String {
        """
        Change the Openspot spot in \(file.path): \(wish)
        \(Self.finishChange)
        \(evidence.map { "\n\($0.text)\n" } ?? "")
        \(steps(for: SpotID(file: file).description))
        """
    }

    public func copying(_ core: URL, to copy: URL) -> String {
        "This spot comes with Openspot. First copy its folder \(core.path) to \(copy.path), with the same folder name. The copy takes the place of the built-in spot, so make each change in the copy, and leave the folder in the app as it is."
    }

    public func changing(_ file: URL, failure: String?, evidence: SpotEvidence? = nil) -> String {
        let failed = failure.map { "Its last call failed, and said: \($0)\n" } ?? ""
        if let evidence { return changing(file, wish: ([evidence.goal] + (failure.map { ["Its last call failed, and said: \($0)"] } ?? [])).joined(separator: "\n"), evidence: evidence) }
        return """
        Change the Openspot spot in \(file.path). Ask me what to change before you change it.
        \(failed)
        \(steps(for: SpotID(file: file).description))
        """
    }

    private func steps(for id: String) -> String {
        """
        First run "\(app)" guide, and read all of it.
        Try each call with "\(app)" spot run \(id) [call] [value]..., and look at its card with "\(app)" render spot \(id) --card wide card.png.
        When it is ready, run "\(app)" check spots --json "\(folder.path)" and fix each fault until it prints [].
        At the end of your answer, run "\(app)" spot open \(id) --select, and tell me what the spot runs on my computer.

        """
    }

    func copy(_ text: String, base: [String: String]? = nil) async throws -> String {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["LC_ALL=en_US.UTF-8", "pbcopy"], input: text, base: base)
        return Self.copied
    }
}
