import Foundation

/// The New spot sheet, which ships with the app. It asks what a spot should do and copies a prompt for a coding agent, or
/// makes a working spot from a starter, and opens the guide and the plugins folder. It answers the calls a sheet script
/// answers, in Swift.
public struct NewSpot: Equatable, Sendable {
    static let askPart = "ask"
    static let buildPart = "build"
    static let guidePart = "guide"
    static let folderPart = "folder"

    public let folder: URL
    public let guide: URL
    public let prompt: AgentPrompt

    public init(folder: URL, guide: URL, prompt: AgentPrompt) {
        self.folder = folder
        self.guide = guide
        self.prompt = prompt
    }

    /// Answers one call with the text a script would print.
    public func answer(_ arguments: [String], input: String?) async throws -> String {
        switch arguments.first {
        case "read":
            return sheet
        case Self.buildPart:
            return try await build(TextBlock.blocks(in: input ?? "").first?.value(Self.askPart) ?? "")
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

    /// Copies a prompt that asks an agent to build a spot that does what the person described.
    private func build(_ description: String) async throws -> String {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw PluginError.fault("Write what the spot should do, then press `⌘⏎`.") }
        return toast(try await prompt.copy(prompt.building(text)))
    }

    /// The sheet: the field that says what to build and its button, a button for each starter, and the guide and the folder.
    private var sheet: String {
        let head = TextBlock(fields: [
            "ask ask", "build build", "starters starters", "button list", "number form", "- -", "guide folder"
        ].map { TextBlock.Field(key: "grid", value: $0) })
        let ask = TextBlock(fields: [
            .init(key: "field", value: Self.askPart),
            .init(key: "title", value: "What should it do?"),
            .init(key: "placeholder", value: "Show the weather here")
        ])
        let build = button(Self.buildPart, "Copy prompt for AI", ["shortcut": "cmd+return", "look": "strong", "close": "true"])
        let section = TextBlock(fields: [.init(key: "section", value: "starters"), .init(key: "title", value: "Or start from")])
        let starters = SpotStarter.allCases.map { starter in
            button(starter.rawValue, starter.title, ["close": "true"])
        }
        let links = [button(Self.guidePart, "Read the guide", ["look": "chip"]), button(Self.folderPart, "Open plugins folder", ["look": "chip"])]
        return ([head, ask, build, section] + starters + links).map(\.text).joined(separator: "\n")
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
