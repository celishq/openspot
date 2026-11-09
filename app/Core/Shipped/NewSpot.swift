import Foundation

/// The New spot sheet, which ships with the app. It asks what a spot should do and gives that to a coding agent, or makes a
/// working spot from a starter, and opens the guide and the plugins folder. It answers the calls a sheet script answers, in
/// Swift.
public struct NewSpot: Equatable, Sendable {
    /// The detail of a placeholder that an agent builds, which its card shows as running work.
    public static let buildingDetail = "Your agent is building it"
    static let askPart = "ask"
    static let buildPart = "build"
    static let agentPart = "agent"
    static let guidePart = "guide"
    static let folderPart = "folder"
    private static let titleWords = 4

    public let folder: URL
    public let guide: URL
    public let handoff: AgentHandoff
    public let config: ConfigFile

    public init(folder: URL, guide: URL, handoff: AgentHandoff, config: ConfigFile) {
        self.folder = folder
        self.guide = guide
        self.handoff = handoff
        self.config = config
    }

    /// Answers one call with the text a script would print.
    public func answer(_ arguments: [String], input: String?) async throws -> String {
        switch arguments.first {
        case "read":
            return await sheet
        case Self.buildPart:
            return try await build(TextBlock.blocks(in: input ?? "").first?.value(Self.askPart) ?? "")
        case Self.agentPart:
            try config.set(setting: Self.agentPart, of: ShippedSpot.newID, to: arguments.dropFirst().first)
            return ""
        case let word? where SpotStarter(rawValue: word) != nil:
            let name = SpotStarter.freeName("Untitled", in: folder)
            let file = try SpotStarter(rawValue: word)!.write(name: name, in: folder)
            try await tool(["open", "-t", file.path])
            return toast("Made \(name). Change the file that opened to make it yours.")
        case Self.guidePart:
            try await tool(["open", guide.path])
            return ""
        case Self.folderPart:
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try await tool(["open", folder.path])
            return ""
        default:
            throw PluginError.failed(1, "New spot cannot do that.")
        }
    }

    /// Makes a placeholder spot named after the first words of the description, which shows on the grid at once, and gives
    /// the agent the description and the placeholder to build in.
    private func build(_ description: String) async throws -> String {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw PluginError.fault("Write what the spot should do, then press `⌘⏎`.") }
        let words = text.split(whereSeparator: \.isWhitespace).prefix(Self.titleWords).joined(separator: " ")
        let title = words.prefix(1).uppercased() + words.dropFirst().trimmingCharacters(in: .punctuationCharacters)
        let file = try SpotStarter.write(name: SpotStarter.freeName(title, in: folder), in: folder) { title in
            """
            #!/bin/sh
            # title=\(title)
            # icon=hammer
            # detail=\(Self.buildingDetail)
            echo 'toast=Your agent is still building this spot.'

            """
        }
        let choice = config.read().setting(Self.agentPart, of: ShippedSpot.newID)
        return toast(try await handoff.hand(handoff.prompt.building(text, in: file), choice: choice, doing: "building it"))
    }

    /// The sheet: the field that says what to build, the agent and its button, a button for each starter, and the guide and
    /// the folder.
    private var sheet: String {
        get async {
            let found = await handoff.agents().map(\.agent)
            let chosen = config.read().setting(Self.agentPart, of: ShippedSpot.newID)
            let options = found.map { ($0.rawValue, $0.title) } + [(AgentHandoff.copy, "Copy the prompt")]
            let value = options.first { $0.0 == chosen }?.0 ?? options[0].0
            let head = TextBlock(fields: [
                "ask ask", "agent build", "starters starters", "button list", "number form", "- -", "guide folder"
            ].map { TextBlock.Field(key: "grid", value: $0) })
            let ask = TextBlock(fields: [
                .init(key: "field", value: Self.askPart),
                .init(key: "title", value: "What should it do?"),
                .init(key: "placeholder", value: "Show the weather here")
            ])
            let agent = TextBlock(fields: [.init(key: "choice", value: Self.agentPart)]
                + options.map { TextBlock.Field(key: "option", value: "\($0.0):\($0.1)") } + [.init(key: "value", value: value)])
            let build = button(Self.buildPart, "Build with AI", ["shortcut": "cmd+return", "look": "strong", "close": "true"])
            let section = TextBlock(fields: [.init(key: "section", value: "starters"), .init(key: "title", value: "Or start from")])
            let starters = SpotStarter.allCases.map { starter in
                button(starter.rawValue, starter.title, ["close": "true"])
            }
            let links = [button(Self.guidePart, "Read the guide", ["look": "chip"]), button(Self.folderPart, "Open plugins folder", ["look": "chip"])]
            return ([head, ask, agent, build, section] + starters + links).map(\.text).joined(separator: "\n")
        }
    }

    private func button(_ id: String, _ title: String, _ keys: KeyValuePairs<String, String>) -> TextBlock {
        TextBlock(fields: [.init(key: "button", value: id), .init(key: "title", value: title)] + keys.map { TextBlock.Field(key: $0.key, value: $0.value) })
    }

    private func toast(_ text: String) -> String {
        TextBlock(fields: [.init(key: "toast", value: text)]).text
    }

    private func tool(_ arguments: [String]) async throws {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: arguments)
    }
}
