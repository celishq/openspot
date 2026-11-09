import Foundation

/// The New spot sheet, which ships with the app. It is a list that the search field fills: its first row copies a prompt
/// that asks a coding agent to build what the person typed, and a row for each starter makes a working spot. Its actions
/// open the guide and the plugins folder. It answers the calls a sheet script answers, in Swift.
public struct NewSpot: Equatable, Sendable {
    static let askRow = "ask"
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
        switch (arguments.first, arguments.dropFirst().first) {
        case ("read", let text):
            return sheet(asking: text ?? "")
        case ("open", Self.askRow?):
            return try await build(TextBlock.blocks(in: input ?? "").first?.value("search") ?? "")
        case ("open", let row?) where SpotStarter(rawValue: row) != nil:
            let name = SpotStarter.freeName("Untitled", in: folder)
            let file = try SpotStarter(rawValue: row)!.write(name: name, in: folder)
            try await tool(["open", "-t", file.path])
            return toast("Made \(name). Change the file that opened to make it yours.")
        case (Self.guidePart?, _):
            try await tool(["open", guide.path])
            return ""
        case (Self.folderPart?, _):
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
        guard !text.isEmpty else { throw PluginError.fault("Type what the spot should do, then press `⏎`.") }
        return toast(try await prompt.copy(prompt.building(text)))
    }

    /// The list: the row that copies a prompt with the text of the search, a row for each starter, and the actions that open
    /// the guide and the folder.
    private func sheet(asking text: String) -> String {
        let head = TextBlock(fields: [.init(key: "search", value: "script"), .init(key: "recents", value: "false")])
        let actions = [
            button("open", "Choose", [:]),
            button(Self.guidePart, "Read the guide", ["scope": "command", "close": "true"]),
            button(Self.folderPart, "Open plugins folder", ["scope": "command", "close": "true"])
        ]
        let ask = row(Self.askRow, "Copy prompt for AI", text.isEmpty ? "Type what the spot should do" : text, "sparkles")
        let starters = SpotStarter.allCases.map { row($0.rawValue, $0.title, $0.detail, $0.symbol) }
        return ([head] + actions + [ask] + starters).map(\.text).joined(separator: "\n")
    }

    private func row(_ id: String, _ title: String, _ detail: String, _ icon: String) -> TextBlock {
        TextBlock(fields: [.init(key: "row", value: id), .init(key: "title", value: title), .init(key: "detail", value: detail), .init(key: "icon", value: icon)])
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
