import Foundation

/// The Spots spot, which ships with the app. It lists the core spots, and a pick turns one on or off.
public struct CatalogSpot: Equatable, Sendable {
    /// The row that opens the Build spot, which the panel answers.
    public static let buildRun = "openspot.build"
    /// The action that shows the text of a core spot, which the panel answers.
    public static let reviewID = "openspot.review"
    /// The action that turns each core spot on.
    public static let selectAllID = "openspot.select-all"

    public let folder: URL
    public let core: URL?
    public let config: ConfigFile
    /// The row that a first launch offers.
    public let login: LoginItem?

    public init(folder: URL, core: URL?, config: ConfigFile, login: LoginItem? = nil) {
        self.folder = folder
        self.core = core
        self.config = config
        self.login = login
    }

    /// Answers one call with the text a script would print. A change prints nothing, which asks for a new read.
    public func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "read":
            return rows
        case Self.selectAllID:
            try selectAll()
            return ""
        case "open" where arguments.dropFirst().first == LoginItem.run:
            try login?.toggle()
            return ""
        case "open":
            return try toggle(arguments.dropFirst().first ?? "")
        default:
            throw PluginError.failed(1, "Spots cannot do that.")
        }
    }

    private func toggle(_ id: String) throws -> String {
        guard choices.contains(where: { PluginFolder.coreID(of: $0) == id }) else { throw PluginError.failed(1, "Spots has no such spot.") }
        if own.contains(id) { return "toast=This spot is a file in your plugins folder.\n" }
        try config.turn(id, on: !config.read().arrangement.enabled.contains(id))
        return ""
    }

    /// Turns each core spot on. A file in the plugins folder stays as it is, because it is always on.
    private func selectAll() throws {
        let own = own
        var arrangement = config.read().arrangement
        for command in choices {
            let id = PluginFolder.coreID(of: command)
            if !own.contains(id) { arrangement.set(isEnabled: true, of: id) }
        }
        try config.write(arrangement)
    }

    private var choices: [Spot] {
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
            TextBlock(fields: [.init(key: "button", value: "open"), .init(key: "title", value: "Select"), .init(key: "close", value: "false")]),
            TextBlock(fields: [.init(key: "button", value: Self.selectAllID), .init(key: "title", value: "Select all"), .init(key: "key", value: "cmd+shift+a"), .init(key: "scope", value: "command")]),
            TextBlock(fields: [.init(key: "button", value: Self.reviewID), .init(key: "title", value: "Review code")])
        ]
        let spots = choices.map { command in
            let id = PluginFolder.coreID(of: command)
            var fields: [TextBlock.Field] = [.init(key: "row", value: id), .init(key: "title", value: command.name), .init(key: "symbol", value: command.symbol)]
            fields += [("image", command.image), ("file", command.file), ("glyph", command.glyph)].compactMap { key, value in value.map { .init(key: key, value: $0) } }
            let detail = own.contains(id) ? "In your plugins folder" : command.subtitle
            if let detail { fields.append(.init(key: "detail", value: detail)) }
            fields.append(.init(key: "on", value: String(own.contains(id) || enabled.contains(id))))
            return TextBlock(fields: fields)
        }
        let build = TextBlock(fields: [
            .init(key: "row", value: Self.buildRun),
            .init(key: "title", value: "Build your own"),
            .init(key: "detail", value: "Make a spot, or read how they work"),
            .init(key: "symbol", value: "hammer"),
            .init(key: "hides", value: Self.reviewID)
        ])
        let loginRow = login.map { TextBlock(fields: $0.row.fields + [.init(key: "hides", value: Self.reviewID)]) }
        return (head + spots + (loginRow.map { [$0] } ?? []) + [build]).map(\.text).joined(separator: "\n")
    }
}
