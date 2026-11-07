import Foundation

/// The Spots spot, which ships with the app. It lists the core spots, and a pick turns one on or off.
public struct SpotCatalog: Equatable, Sendable {
    /// The row that opens the Build spot, which the panel answers.
    public static let buildRun = "openspot.build"
    /// The action that shows the text of a core spot, which the panel answers.
    public static let reviewID = "openspot.review"

    public let folder: URL
    public let core: URL?
    public let config: ConfigFile

    public init(folder: URL, core: URL?, config: ConfigFile) {
        self.folder = folder
        self.core = core
        self.config = config
    }

    /// Answers one call with the text a script would print. A change prints nothing, which asks for a new read.
    public func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "read":
            return rows
        case "open":
            return try toggle(arguments.dropFirst().first ?? "")
        default:
            throw PluginError.failed(1, "Spots cannot do that.")
        }
    }

    private func toggle(_ id: String) throws -> String {
        guard choices.contains(where: { $0.id == id }) else { throw PluginError.failed(1, "Spots has no such spot.") }
        if own.contains(id) { return "toast=This spot is a file in your plugins folder.\n" }
        try config.turn(id, on: !config.read().arrangement.enabled.contains(id))
        return ""
    }

    private var choices: [PluginCommand] {
        PluginFolder(url: folder, core: core).coreChoices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The IDs in the plugins folder, which always stay on.
    private var own: Set<String> {
        Set(((try? PluginFolder(url: folder).scan())?.plugins ?? []).map(\.id))
    }

    private var rows: String {
        let enabled = config.read().arrangement.enabled
        let own = own
        let head = [
            TextBlock(fields: [.init(key: "recents", value: "false")]),
            TextBlock(fields: [.init(key: "action", value: "open"), .init(key: "title", value: "Select"), .init(key: "close", value: "false")]),
            TextBlock(fields: [.init(key: "action", value: Self.reviewID), .init(key: "title", value: "Review code")])
        ]
        let spots = choices.map { command in
            var fields: [TextBlock.Field] = [.init(key: "row", value: command.name), .init(key: "run", value: command.id), .init(key: "symbol", value: command.symbol)]
            let detail = own.contains(command.id) ? "In your plugins folder" : command.subtitle
            if let detail { fields.append(.init(key: "detail", value: detail)) }
            fields.append(.init(key: "on", value: String(own.contains(command.id) || enabled.contains(command.id))))
            return TextBlock(fields: fields)
        }
        let build = TextBlock(fields: [
            .init(key: "row", value: "Build your own"),
            .init(key: "detail", value: "Make a spot, or read how they work"),
            .init(key: "run", value: Self.buildRun),
            .init(key: "symbol", value: "hammer"),
            .init(key: "hides", value: Self.reviewID)
        ])
        return (head + spots + [build]).map(\.text).joined(separator: "\n")
    }
}
