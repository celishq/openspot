import Foundation

/// One executable of a plugin, with the look its spot takes. A widget runs nothing, and places scripts in a layout.
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
    public let order: Int
    public private(set) var keepsRecent = true
    public private(set) var primary: String?
    public private(set) var actions: [CommandAction]
    public let layout: WidgetLayout?
    public let places: [String]
    public let opens: String?
    public let shipped: ShippedSpot?
    /// Whether the script stays running and takes calls on its standard input.
    public let stays: Bool
    /// The file extensions that its card takes, with `folder` and `*`.
    public let drop: [String]
    /// Whether the menu bar shows it.
    public let isTray: Bool
    /// Whether it has a card. A script with a number in its `read` and no `key` has none (F7).
    public let hasSpot: Bool
    /// The `symbol` its header names, if any.
    public let headerSymbol: String?

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
        order: Int = 0,
        primary: String? = nil,
        actions: [CommandAction] = [],
        layout: WidgetLayout? = nil,
        places: [String] = [],
        opens: String? = nil,
        shipped: ShippedSpot? = nil,
        stays: Bool = false,
        drop: [String] = [],
        isTray: Bool = false,
        hasSpot: Bool = true,
        headerSymbol: String? = nil
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
        self.order = order
        self.primary = primary
        self.actions = actions
        self.layout = layout
        self.places = places
        self.opens = opens
        self.shipped = shipped
        self.stays = stays
        self.drop = drop
        self.isTray = isTray
        self.hasSpot = hasSpot
        self.headerSymbol = headerSymbol
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
        read?.has(.panel) == true && !isGlobal && !stays
    }

    /// The call that a click on its card makes: `run`, or no argument for a file with no `read`.
    public var click: SpotAction {
        read == nil ? SpotAction(arguments: []) : .run
    }

    /// This command with the actions, the word for Enter, the pick and the recents that its script printed, and the kind it
    /// makes when the panel asks it how it looks.
    public func taking(_ output: PluginOutput) -> PluginCommand {
        var command = self
        command.actions = output.actions
        command.primary = output.primary
        command.pick = output.pick
        command.keepsRecent = output.keepsRecent
        if readsState { command.kind = output.kind }
        return command
    }

    /// The state that an output gives. A command with no state to read keeps its header.
    public func state(of output: PluginOutput) throws -> SpotState {
        guard readsState else { return headerState }
        guard output.summary != nil || output.errors.isEmpty else { throw PluginError.badState }
        return SpotState(block: output.summary, header: headerState)
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

    public func withoutKey() -> PluginCommand {
        var command = self
        command.key = nil
        return command
    }
}
