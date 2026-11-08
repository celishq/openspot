import Foundation

/// One executable of a plugin, with the look its spot takes. A widget runs nothing, and places scripts in a layout.
public struct Spot: Equatable, Sendable {
    private static let folderWord = "folder"
    private static let anyWord = "*"

    public let id: String
    public let name: String
    public let url: URL
    public private(set) var kind: SpotKind
    public let size: SpotSize
    public let symbol: String
    public let subtitle: String?
    public private(set) var key: CommandKey?
    public private(set) var read: SpotRead?
    public private(set) var pick: ItemPick
    /// Whether its rows join the main search.
    public let isGlobal: Bool
    /// Its place in the grid before the person's choice: a lower number first. The person's newest file comes first.
    public private(set) var order: Int
    public private(set) var keepsRecent = true
    public private(set) var primary: String?
    public private(set) var actions: [CommandAction]
    public let layout: WidgetLayout?
    public let places: [String]
    public let opens: String?
    public let shipped: ShippedSpot?
    /// The file extensions that its card takes, with `folder` and `*`.
    public let drop: [String]
    /// Whether the menu bar shows it.
    public let isTray: Bool
    /// The folder of its files inside the data of the app. A shipped spot and a widget have none.
    public let dataName: String?
    /// Whether it has a card. A script with a number in its `read` and no `key` has none (F7).
    public let hasSpot: Bool
    /// Whether the grid shows its card. A script with commands, or one that a widget opens, has no card on the grid.
    public private(set) var isOnGrid: Bool
    /// The `symbol` its header names, if any.
    public let headerSymbol: String?
    /// The file whose icon its header names, as a full path.
    public let file: String?
    /// The image its header names, as a full path.
    public let image: String?
    /// The short text, such as an emoji, that its header names as its picture.
    public let glyph: String?
    /// The Swift file of the view that its card draws, as a full path (V1).
    public let view: String?
    /// The commands its header lists, which a person can give keys.
    public let offers: [CommandOffer]
    /// The Settings rows of its own commands, which its sheet shows. Nil for a spot that draws its own sheet.
    public private(set) var keyList: SettingsSpot?

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
        isGlobal: Bool = false,
        order: Int = 0,
        primary: String? = nil,
        actions: [CommandAction] = [],
        layout: WidgetLayout? = nil,
        places: [String] = [],
        opens: String? = nil,
        shipped: ShippedSpot? = nil,
        drop: [String] = [],
        isTray: Bool = false,
        dataName: String? = nil,
        hasSpot: Bool = true,
        isOnGrid: Bool = true,
        headerSymbol: String? = nil,
        offers: [CommandOffer] = [],
        file: String? = nil,
        image: String? = nil,
        glyph: String? = nil,
        view: String? = nil
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
        self.isGlobal = isGlobal
        self.order = order
        self.primary = primary
        self.actions = actions
        self.layout = layout
        self.places = places
        self.opens = opens
        self.shipped = shipped
        self.drop = drop
        self.isTray = isTray
        self.dataName = dataName
        self.hasSpot = hasSpot
        self.isOnGrid = isOnGrid
        self.headerSymbol = headerSymbol
        self.offers = offers
        self.file = file
        self.image = image
        self.glyph = glyph
        self.view = view
    }

    /// The picture its header names in place of its symbol: its image, or else the icon of its file.
    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }

    /// The sizes a person can prefer for its card. A widget has the size of its layout, and Updates needs room for its words.
    public var sizes: [SpotSize] {
        if kind == .widget { return [] }
        if case .updates? = shipped { return SpotSize.all.filter { $0.columns > 1 } }
        return SpotSize.all
    }

    /// The same spot, which opens to the keys of its commands when it lists commands and has no read of its own.
    func listingKeys(with settings: SettingsSpot) -> Spot {
        guard !offers.isEmpty, read == nil, shipped == nil else { return self }
        var spot = self
        spot.kind = .list
        spot.read = .sheet
        spot.keyList = settings.keys(of: id)
        return spot
    }

    /// The same spot, placed in the grid by the date its file was added: the newest first.
    func added(at date: Date) -> Spot {
        var spot = self
        spot.order = -Int(date.timeIntervalSince1970)
        return spot
    }

    /// The same spot, off the grid.
    func offTheGrid() -> Spot {
        var spot = self
        spot.isOnGrid = false
        return spot
    }

    /// Whether its sheet changes the keys in the config file.
    public var setsKeys: Bool {
        if case .settings? = shipped { return true }
        return keyList != nil
    }

    /// The state the header gives, shown before the command answers or when it cannot.
    public var headerState: SpotState {
        SpotState(title: name, subtitle: subtitle, isOnGrid: isOnGrid)
    }

    /// Whether the panel asks the command how it looks each time it opens.
    public var readsState: Bool {
        read?.has(.panel) == true && !isGlobal
    }

    /// The call that a click on its card makes: `run`, or no argument for a file with no `read`.
    public var click: SpotAction {
        read == nil ? SpotAction(arguments: []) : .run
    }

    /// Whether its `drop` takes files that are not folders.
    public var takesFiles: Bool {
        dropWords.contains { !$0.isEmpty && $0 != Self.folderWord }
    }

    /// Whether its `drop` takes folders: the word `folder` or `*`. A bundle, such as an app, is a folder.
    public var takesFolders: Bool {
        dropWords.contains(Self.folderWord) || dropWords.contains(Self.anyWord)
    }

    /// Whether its card takes anything that a person drops.
    public var takesDrops: Bool {
        takesFiles || takesFolders
    }

    /// Whether its card takes all these files at once. One that does not fit, or that is not on the disk, refuses all.
    public func accepts(_ paths: [String]) -> Bool {
        !paths.isEmpty && paths.allSatisfy(accepts(path:))
    }

    private func accepts(path: String) -> Bool {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder) else { return false }
        if isFolder.boolValue { return takesFolders }
        let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        if dropWords.contains(Self.anyWord) { return true }
        return !fileExtension.isEmpty && fileExtension != Self.folderWord && dropWords.contains(fileExtension)
    }

    private var dropWords: [String] {
        drop.map { $0.lowercased() }
    }

    /// This command with the actions, the word for Enter, the pick and the recents that its script printed, and the kind it
    /// makes when the panel asks it how it looks.
    public func taking(_ output: PluginOutput) -> Spot {
        var command = self
        command.actions = output.actions
        command.primary = output.primary
        command.pick = output.pick
        command.keepsRecent = output.keepsRecent
        if readsState { command.kind = output.kind }
        return command
    }

    /// The state that an output gives, with each value of its head for a view. A command with no state to read keeps its
    /// header.
    public func state(of output: PluginOutput) throws -> SpotState {
        guard readsState else { return headerState }
        guard output.summary != nil || output.errors.isEmpty else { throw PluginError.badState }
        var state = SpotState(output: output, header: headerState)
        if view != nil { state = state.holding(output.summary) }
        guard shipped != nil, let isOnGrid = output.summary?.flag("grid") else { return state }
        return state.onGrid(isOnGrid)
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

    public func withoutKey() -> Spot {
        var command = self
        command.key = nil
        return command
    }
}
