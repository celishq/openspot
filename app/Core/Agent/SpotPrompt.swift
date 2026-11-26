import Foundation

public struct SpotPrompt: Equatable, Sendable {
    public let folder: URL
    public let references: [URL]
    public let app: String

    public init(folder: URL, references: [URL], app: String) {
        self.folder = folder
        self.references = references
        self.app = app
    }

    public init(places: AppPlaces) {
        self.init(folder: places.spots.url, references: [places.spots.core, places.examples?.url].compactMap { $0 }, app: Self.command())
    }

    public static func command(of app: String = Bundle.main.executablePath ?? "openspot") -> String {
        let contents = URL(fileURLWithPath: app).deletingLastPathComponent().deletingLastPathComponent()
        let client = contents.appendingPathComponent("Helpers/openspot").path
        return FileManager.default.isExecutableFile(atPath: client) ? client : app
    }

    public static let copied = "Prompt copied. Paste it into your agent."
    static let wordsNeeded = "Say what the spot should do, such as `openspot prompt new show the weather in Kyiv`."
    static let finishNew = "Choose a short name and sensible defaults yourself, and build it to the end."
    static let finishChange = "Make the change to the end, and keep what already works."
    static let review = "Find what works poorly in this spot, such as a call that fails, a slow answer, work while the panel is hidden or a card that looks wrong, and fix it. If nothing does, change nothing and tell me why."
    static let simplest = "Build it the simplest way that does it, as the guide's Choose how to build it says. If you take a way past a shell script, tell me why."
    static let loadAgain = "Make Openspot load this spot again, and keep what it does."

    public func building(_ description: String) -> String {
        AgentPrompt(
            app: app,
            task: "Build a new spot that does what my request says.",
            place: place + ["Make the spot in a new folder of the spots folder."],
            reading: reading,
            finish: Self.finishNew,
            rules: rules(for: "<id>"),
            request: description
        ).text
    }

    public func fixing(_ file: URL, faults: [String]) -> String {
        brief(of: file, task: "Openspot does not load this spot. Fix it.", facts: ["Openspot says:\n" + faults.joined(separator: "\n")], request: Self.loadAgain)
    }

    public func changing(_ file: URL, wish: String? = nil, failure: String? = nil, evidence: SpotEvidence? = nil) -> String {
        let facts = [failure.map { "Its last call failed, and said: \($0)" }, evidence?.text].compactMap { $0 }
        return brief(of: file, task: "Change this spot as my request says.", facts: facts, request: wish ?? evidence?.goal ?? Self.review)
    }

    func readChange(of file: URL, id: String, wish: String?, failure: String?, runs: SpotRuns?, stats: URL) async -> String {
        changing(file, wish: wish, failure: failure, evidence: await SpotEvidence.read(of: id, runs: runs, stats: stats, app: app))
    }

    private func brief(of file: URL, task: String, facts: [String], request: String) -> String {
        let id = SpotID(file: file).description
        return AgentPrompt(
            app: app,
            task: task,
            place: place + ["The spot \(id) is in \(file.deletingLastPathComponent().path), and its main file is \(file.path)."],
            reading: ["Read each file of the spot.", "Run \(quoted) spot log \(id). It prints the last calls that Openspot made to it."] + facts + reading,
            finish: Self.finishChange,
            rules: rules(for: id),
            request: request
        ).text
    }

    private var quoted: String {
        AgentPrompt.quoted(app)
    }

    private var place: [String] {
        ["The spots folder is \(folder.path)."]
    }

    private var reading: [String] {
        let close = references.isEmpty ? [] : ["Find a spot that does something close in \(references.map(\.path).joined(separator: " or ")), and read it."]
        return [
            "Run \(quoted) guide build-and-check-a-spot, and follow it.",
            "Run \(quoted) guide for the map of the guide. Print only the parts that the request needs: a page or a page/section by its address, and \(quoted) guide <word> for the row of a key, a block, a class or a command."
        ] + close
    }

    private func rules(for id: String) -> [String] {
        [
            Self.simplest,
            "It's done when \(quoted) check spots --json \"\(folder.path)\" prints [], and its card looks right in \(quoted) render spot \(id) --card wide card.png.",
            "At the end, run \(quoted) spot open \(id) --select, and tell me what the spot runs on my Mac."
        ]
    }

    func copy(_ text: String, base: [String: String]? = nil) async throws -> String {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["LC_ALL=en_US.UTF-8", "pbcopy"], input: text, base: base)
        return Self.copied
    }
}
