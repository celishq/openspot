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
    public private(set) var read: SpotRead?
    public private(set) var pick: ItemPick
    /// The form that Enter on a row asks with first, from the last output of its script.
    public private(set) var pickForm: CommandAction?
    /// Whether its rows join the main search.
    public let isGlobal: Bool
    /// Whether the main search finds the spot itself. A header with `offers=rows` offers only its rows.
    public let isFound: Bool
    /// The text of the main search that its script answers with rows (A1).
    public let answers: AnswerPattern?
    /// Its place in the grid before the person's choice: a lower number first. The person's newest file comes first.
    public private(set) var order: Int
    public private(set) var keepsRecent = true
    public private(set) var primary: String?
    public private(set) var actions: [CommandAction]
    public let layout: WidgetLayout?
    public let places: [String]
    public let opens: String?
    public let shipped: ShippedSpot?
    /// Whether the script stays running and takes calls on its standard input.
    public let stays: Bool
    /// Whether the script stays running from the start of the app to its quit.
    public let staysAlways: Bool
    /// The file extensions that its card takes, with `folder` and `*`.
    public let drop: [String]
    /// Whether its header offers it as a float, which the person can give a key or a shake (T1).
    public let offersFloat: Bool
    /// The folder of its files inside the data of the app. A shipped spot and a widget have none.
    public let dataName: String?
    /// Whether the grid shows its card before the person's choice. A script with commands, one that offers only its rows,
    /// one with a number in its `read` (F7), or one that a widget opens, has no card on the grid.
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
    /// The values that it keeps with `openspot setting`, each with its title, which Settings lists.
    public let settings: [CommandOffer]
    /// The Settings rows of its own commands, which its sheet shows. Nil for a spot that draws its own sheet.
    public private(set) var keyList: SettingsSpot?
    /// The sizes that a person can prefer for its card, when it offers fewer than all.
    private let sizeChoices: [SpotSize]?
    /// Whether its own sheet changes the keys in the config file.
    private let changesKeys: Bool
    /// Whether it reads again when an update of the app is ready.
    public let readsOnUpdate: Bool
    /// The spot whose sheet a pick of each of these rows opens, by the row's ID.
    public let rowOpens: [String: String]
    /// The action that shows the code of the core spot that a row names.
    public let reviewAction: String?
    /// Whether its sheet turns spots on or off, so that the grid loads again under it.
    public let changesSpots: Bool
    /// The prompt that asks an agent to write or fix a spot, which a card that does not load and Copy prompt use.
    public let agentPrompt: AgentPrompt?
    /// Whether the settings key of the Mac opens its sheet.
    public let opensWithSettingsKey: Bool
    /// Whether ⌘N on the grid opens its sheet.
    public let opensWithNewKey: Bool
    /// Whether it comes with the app as a part of it: always on, and never edited, removed or shared as a file of the
    /// person's.
    public private(set) var isBuiltIn = false

    public init(
        id: String,
        name: String,
        url: URL,
        kind: SpotKind = .launch,
        size: SpotSize = .wide,
        symbol: String = "app",
        subtitle: String? = nil,
        read: SpotRead? = nil,
        pick: ItemPick = .close,
        isGlobal: Bool = false,
        isFound: Bool = true,
        answers: AnswerPattern? = nil,
        order: Int = 0,
        primary: String? = nil,
        actions: [CommandAction] = [],
        layout: WidgetLayout? = nil,
        places: [String] = [],
        opens: String? = nil,
        shipped: ShippedSpot? = nil,
        stays: Bool = false,
        staysAlways: Bool = false,
        drop: [String] = [],
        offersFloat: Bool = false,
        dataName: String? = nil,
        isOnGrid: Bool = true,
        headerSymbol: String? = nil,
        offers: [CommandOffer] = [],
        settings: [CommandOffer] = [],
        file: String? = nil,
        image: String? = nil,
        glyph: String? = nil,
        view: String? = nil,
        sizes: [SpotSize]? = nil,
        setsKeys: Bool = false,
        readsOnUpdate: Bool = false,
        rowOpens: [String: String] = [:],
        reviewAction: String? = nil,
        changesSpots: Bool = false,
        agentPrompt: AgentPrompt? = nil,
        opensWithSettingsKey: Bool = false,
        opensWithNewKey: Bool = false
    ) {
        self.opensWithNewKey = opensWithNewKey
        self.agentPrompt = agentPrompt
        self.opensWithSettingsKey = opensWithSettingsKey
        self.rowOpens = rowOpens
        self.reviewAction = reviewAction
        self.changesSpots = changesSpots
        sizeChoices = sizes
        changesKeys = setsKeys
        self.readsOnUpdate = readsOnUpdate
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.size = size
        self.symbol = symbol
        self.subtitle = subtitle
        self.read = read
        self.pick = pick
        self.isGlobal = isGlobal
        self.isFound = isFound
        self.answers = answers
        self.order = order
        self.primary = primary
        self.actions = actions
        self.layout = layout
        self.places = places
        self.opens = opens
        self.shipped = shipped
        self.stays = stays
        self.staysAlways = staysAlways
        self.drop = drop
        self.offersFloat = offersFloat
        self.dataName = dataName
        self.isOnGrid = isOnGrid
        self.headerSymbol = headerSymbol
        self.offers = offers
        self.settings = settings
        self.file = file
        self.image = image
        self.glyph = glyph
        self.view = view
    }

    /// The sheet of the file that does not load, which this card stands for.
    public var fault: FaultSpot? {
        if case .fault(let fault)? = shipped { fault } else { nil }
    }

    /// The picture its header names in place of its symbol: its image, or else the icon of its file.
    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }

    /// The sizes a person can prefer for its card. A widget has the size of its layout.
    public var sizes: [SpotSize] {
        kind == .widget ? [] : sizeChoices ?? SpotSize.all
    }

    /// The SF Symbol of one of its commands: the command's own icon when that is a symbol, or else its own symbol.
    public func symbol(of command: String) -> String {
        Icon(text: offers.first { $0.id == command }?.icon)?.symbol ?? symbol
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

    /// The same spot, as a part of the app.
    func builtIn() -> Spot {
        var spot = self
        spot.isBuiltIn = true
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
        changesKeys || keyList != nil
    }

    /// The state the header gives, shown before the command answers or when it cannot.
    public var headerState: SpotState {
        SpotState(title: name, subtitle: subtitle, isOnGrid: isOnGrid)
    }

    /// Whether the panel asks the command how it looks each time it opens.
    public var readsState: Bool {
        read?.has(.panel) == true && !isGlobal && !stays
    }

    /// Whether the person can put it in the menu bar: it has a number or an event in its `read`, or it stays.
    public var canShowInMenuBar: Bool {
        read?.seconds != nil || read?.hasEvent == true || stays
    }

    /// The call that a click on its card makes.
    public var click: SpotAction {
        .open
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
        command.pickForm = output.pickForm
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
        if view != nil { state = state.holding(output.view) }
        guard shipped != nil || isBuiltIn, let isOnGrid = output.summary?.flag("grid") else { return state }
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
}
