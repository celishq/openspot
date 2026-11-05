import Foundation

/// One executable of a plugin, with the look its spot takes. A widget runs nothing, and places metrics in a layout.
public struct PluginCommand: Equatable, Sendable {
    public static let lastRank = Int.max

    public let id: String
    public let name: String
    public let url: URL
    public private(set) var kind: SpotKind
    public let size: SpotSize
    public let symbol: String
    public let subtitle: String?
    public private(set) var key: CommandKey?
    public let read: SpotRead?
    public private(set) var pick: ItemPick
    public let rank: Int
    public let search: ItemSearch
    public let keepsRecent: Bool
    public private(set) var primary: String?
    public private(set) var actions: [CommandAction]
    public let layout: WidgetLayout?
    public let places: [String]
    public let opens: String?

    public init(
        id: String,
        name: String,
        url: URL,
        kind: SpotKind = .launch,
        size: SpotSize = .wide,
        symbol: String = "app",
        subtitle: String? = nil,
        key: CommandKey? = nil,
        read: SpotRead? = nil,
        pick: ItemPick = .close,
        rank: Int = PluginCommand.lastRank,
        search: ItemSearch = .local,
        keepsRecent: Bool = true,
        primary: String? = nil,
        actions: [CommandAction] = [],
        layout: WidgetLayout? = nil,
        places: [String] = [],
        opens: String? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.size = size
        self.symbol = symbol
        self.subtitle = subtitle
        self.key = key
        self.read = read
        self.pick = pick
        self.rank = rank
        self.search = search
        self.keepsRecent = keepsRecent
        self.primary = primary
        self.actions = actions
        self.layout = layout
        self.places = places
        self.opens = opens
    }

    /// Whether its rows join the main search.
    public var isGlobal: Bool {
        rank != Self.lastRank
    }

    /// The state the header gives, shown before the command answers or when it cannot.
    public var headerState: SpotState {
        SpotState(title: name, subtitle: subtitle)
    }

    /// Whether the panel asks the command how it looks each time it opens.
    public var readsState: Bool {
        read == .open && !isGlobal
    }

    /// Asks the command for its state. A command with no state to read does not run.
    public func state(timeout: TimeInterval) async throws -> SpotState {
        guard readsState else { return headerState }
        return try Self.state(of: try await output(.read, timeout: timeout), header: headerState)
    }

    /// Asks the command how it looks, and returns it with the kind and the actions that its output gives.
    public func opened(timeout: TimeInterval) async throws -> (command: PluginCommand, state: SpotState) {
        guard readsState else { return (self, headerState) }
        let output = try await output(.read, timeout: timeout)
        var command = taking(output)
        command.kind = output.kind
        return (command, try Self.state(of: output, header: headerState))
    }

    /// This command with the actions, the word for Enter and the pick that its script printed.
    public func taking(_ output: PluginOutput) -> PluginCommand {
        var command = self
        command.actions = output.actions
        command.primary = output.primary
        command.pick = output.pick
        return command
    }

    private static func state(of output: PluginOutput, header: SpotState) throws -> SpotState {
        guard output.summary != nil || output.errors.isEmpty else { throw PluginError.badState }
        return SpotState(block: output.summary, header: header)
    }

    private func output(_ action: SpotAction, timeout: TimeInterval) async throws -> PluginOutput {
        PluginOutput(text: try await PluginRun(command: self, arguments: action.arguments, timeout: timeout).output())
    }

    /// Asks the command for the items of its list, with the search when it searches live.
    public func items(query: String = "", timeout: TimeInterval) async throws -> PluginOutput {
        try await output(.items(query: query), timeout: timeout)
    }

    /// Asks the command for the form of an action.
    public func form(_ action: CommandAction, item: SpotItem?, timeout: TimeInterval) async throws -> ItemForm {
        guard let form = ItemForm(output: try await output(.form(action, item: item), timeout: timeout)) else { throw PluginError.badForm }
        return form
    }

    /// Gives a filled form to the command, and returns the run value of the item it saved, if it prints one.
    public func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft, timeout: TimeInterval) async throws -> String {
        let output = try await PluginRun(command: self, arguments: SpotAction.action(action, item: item).arguments, timeout: timeout, input: draft.text).output()
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The actions that fit: those an item does not hide, and only the command's own with no item.
    public func actions(for item: SpotItem?) -> [CommandAction] {
        actions.filter { ($0.scope == .command || item != nil) && item?.hides?.contains($0.id) != true }
    }

    /// What Enter does, in words. A slider has no Enter.
    public func primaryTitle(hasItem: Bool) -> String? {
        if hasItem { return primary ?? "Open" }
        switch kind {
        case .launch: return "Run"
        case .toggle: return "Toggle"
        case .list: return "Open"
        case .slider: return nil
        case .widget: return opens == nil ? nil : "Open"
        }
    }

    /// Runs an action, and returns the words of the toast that it prints, if any.
    @discardableResult
    public func perform(_ action: SpotAction, timeout: TimeInterval) async throws -> String? {
        try await output(action, timeout: timeout).summary?.value("toast")
    }

    public func withoutKey() -> PluginCommand {
        var command = self
        command.key = nil
        return command
    }
}
