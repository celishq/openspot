import Foundation

/// One script of a spot, with the look its spot takes. A widget runs nothing, and places scripts in a layout.
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
    /// The text of the main search that its script answers with rows (protocol: Places).
    public let answers: AnswerPattern?
    /// Its place in the grid before the person's choice: a lower number first. The person's newest file comes first.
    public private(set) var order: Int
    public private(set) var keepsRecent = true
    public private(set) var openTitle: String?
    public private(set) var actions: [CommandAction]
    public let layout: WidgetLayout?
    public let places: [String]
    public let opens: String?
    /// The sheet that the app answers in Swift for it, when it is the card of a file that does not load or a review.
    public let host: HostSheet?
    /// Whether its sheet grows out of the search field in place of a card, as the review of a dropped spot does.
    public let growsFromField: Bool
    /// How its script runs.
    public let mode: SpotMode
    /// Whether Enter and a click on its card call `open` though it has a sheet, which ⌘ opens (`press=open`).
    public let pressRuns: Bool
    /// The file extensions that its card takes, with `folder` and `*`.
    public let drop: [String]
    /// Whether its header offers it as a float, which the person can give a key or a shake (protocol: Places).
    public let offersFloat: Bool
    /// The folder of its files inside the data of the app. A sheet of the app and a widget have none.
    public let dataName: String?
    /// Whether the grid shows its card before the person's choice. A script with commands, one that offers only its rows,
    /// one with a number in its `read` (protocol: Places), or one that a widget opens, has no card on the grid.
    public private(set) var isOnGrid: Bool
    /// The `symbol` its header names, if any.
    public let headerSymbol: String?
    /// The file whose icon its header names, as a full path.
    public let file: String?
    /// The image its header names, as a full path.
    public let image: String?
    /// The short text, such as an emoji, that its header names as its picture.
    public let glyph: String?
    /// The Swift file of the view that its card draws, as a full path (protocol: Views).
    public let view: String?
    /// The events that it raises with `openspot event emit`, which its header names in `emits` (protocol: Events).
    public let emits: [String]
    /// The uses that its header names in `uses` (protocol: Trust).
    public internal(set) var uses: Set<SpotUse>
    /// The commands its header lists, which a person can give keys.
    public let offers: [CommandOffer]
    /// The values that it keeps with `openspot setting`, each with its title, which Settings lists.
    public let settings: [CommandOffer]
    /// Its Settings sheet, which the app makes: its place in the menu bar, its keys and its values. Nil for a sheet of the
    /// app, such as a review.
    public private(set) var settingsSheet: SpotSettings?
    /// Whether it is the Settings sheet of a spot, which the app answers. A spot's own sheet never holds its Settings.
    public private(set) var holdsSettings = false
    /// Whether it has no content of its own, only commands, so that opening it opens its Settings.
    public private(set) var opensToSettings = false
    /// Whether it comes with the app as a part of it: always on, and never edited, removed or shared as a file of the
    /// person's.
    public private(set) var isBuiltIn = false
    /// Whether it reaches the account key, whose calls stay out of the call log (protocol: Trust).
    public var reachesAccountKey: Bool {
        SpotUse.reachesAccountKey(uses, isBuiltIn: isBuiltIn)
    }
    /// More words that find it in the main search, beside its name and the words under it.
    public let keywords: [String]
    /// Whether its sheet is also the Edit sheet of each spot, from `edits=spots`, which only a spot of the app can be.
    public let editsSpots: Bool
    /// The file of the person's spot that this Edit sheet changes, or nil for a core spot, whose copy the agent makes.
    public private(set) var editedFile: URL?
    /// Whether its read prints fake data while `OPENSPOT_REASON` is `spot.preview`, for the preview of its listing.
    public let previewsSample: Bool

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
        openTitle: String? = nil,
        actions: [CommandAction] = [],
        layout: WidgetLayout? = nil,
        places: [String] = [],
        opens: String? = nil,
        host: HostSheet? = nil,
        growsFromField: Bool = false,
        mode: SpotMode = .once,
        pressRuns: Bool = false,
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
        emits: [String] = [],
        uses: Set<SpotUse> = [],
        keywords: [String] = [],
        previewsSample: Bool = false,
        editsSpots: Bool = false
    ) {
        self.editsSpots = editsSpots
        self.emits = emits
        self.uses = uses
        self.keywords = keywords
        self.previewsSample = previewsSample
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
        self.openTitle = openTitle
        self.actions = actions
        self.layout = layout
        self.places = places
        self.opens = opens
        self.host = host
        self.growsFromField = growsFromField
        self.mode = mode
        self.pressRuns = pressRuns
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
        if case .fault(let fault)? = host { fault } else { nil }
    }

    /// The picture its header names in place of its symbol: its image, or else the icon of its file.
    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }

    /// The sizes a person can prefer for its card. A widget has the size of its layout.
    public var sizes: [SpotSize] {
        kind == .widget ? [] : SpotSize.all
    }

    /// The SF Symbol of one of its commands: the command's own icon when that is a symbol, or else its own symbol.
    public func symbol(of command: String) -> String {
        Icon(text: offers.first { $0.id == command }?.icon)?.symbol ?? symbol
    }

    /// The one command of a spot with no content of its own, which Return runs.
    public var soleCommand: String? {
        guard host == nil, offers.count == 1 else { return nil }
        return offers.first?.id
    }

    /// Whether Return opens another view of the spot, its sheet, which its card marks with an arrow. A spot that Return runs
    /// shows no arrow and no Run.
    public var opensOnReturn: Bool {
        kind.opensSheet && !pressRuns && soleCommand == nil
    }

    /// Whether Return runs its one command and its own rows open apart, as its History.
    public var keepsHistory: Bool {
        soleCommand != nil && !opensToSettings && read != nil
    }

    /// The same spot, with its Settings sheet in this config. A spot that lists commands and has no read opens to its
    /// Settings.
    func takingSettings(in config: ConfigFile) -> Spot {
        guard host == nil else { return self }
        var spot = self
        spot.settingsSheet = SpotSettings(
            file: config,
            spot: id,
            offers: offers,
            fields: settings,
            offersFloat: offersFloat,
            showsInMenuBar: canShowInMenuBar
        )
        if read == nil, !offers.isEmpty {
            spot.kind = .list
            spot.opensToSettings = true
        }
        return spot
    }

    /// The sheet of its Settings: a list that the app answers, which grows from its card. Nil for that sheet itself.
    public var settingsSpot: Spot? {
        guard let settingsSheet, !holdsSettings else { return nil }
        var spot = Spot(
            id: SpotSettings.sheetID(of: id),
            name: "\(name) Settings",
            url: url,
            kind: .list,
            size: size,
            symbol: symbol,
            read: .sheet,
            isFound: false,
            isOnGrid: false,
            headerSymbol: headerSymbol,
            file: file,
            image: image,
            glyph: glyph
        )
        spot.settingsSheet = settingsSheet
        spot.holdsSettings = true
        return spot
    }

    /// The Edit sheet of a spot, when this spot of the app edits spots: its own sheet, with the spot to change in its
    /// variables, which grows from that spot's card. `isOwn` says whether the file is the person's, which the agent changes
    /// in place, or a core spot's, which it copies first.
    public func editSheet(of owner: Spot, isOwn: Bool) -> Spot? {
        guard editsSpots, isBuiltIn else { return nil }
        var spot = Spot(
            id: OwnedSheet.edit.id(of: owner.id),
            name: "Edit \(owner.name)",
            url: url,
            kind: .list,
            size: owner.size,
            symbol: owner.symbol,
            read: read,
            isFound: false,
            mode: mode,
            dataName: dataName,
            isOnGrid: false,
            headerSymbol: owner.headerSymbol,
            file: owner.file,
            image: owner.image,
            glyph: owner.glyph,
            uses: uses
        )
        spot.isBuiltIn = true
        spot.editedFile = isOwn ? owner.url : nil
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

    /// The state the header gives, shown before the command answers or when it cannot.
    public var headerState: SpotState {
        SpotState(title: name, subtitle: subtitle, isOnGrid: isOnGrid)
    }

    /// Whether the panel asks the command how it looks each time it opens.
    public var readsState: Bool {
        read?.has(.panel) == true && !isGlobal && !mode.stays
    }

    /// Whether the person can put it in the menu bar: every spot but a sheet of the app. One with no value shows its icon.
    public var canShowInMenuBar: Bool {
        host == nil
    }

    /// Whether it shows a value in the menu bar: it has a number or an event in its `read`, or it stays.
    public var showsValueInMenuBar: Bool {
        read?.seconds != nil || read?.hasEvent == true || mode.stays
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
    public func taking(_ output: SpotOutput) -> Spot {
        var command = self
        command.actions = output.actions
        command.openTitle = output.openTitle
        command.pick = output.pick
        command.pickForm = output.pickForm
        command.keepsRecent = output.keepsRecent
        if readsState { command.kind = output.kind }
        return command
    }

    /// The state that an output gives, with each value of its head for a view. A command with no state to read keeps its
    /// header.
    public func state(of output: SpotOutput) throws -> SpotState {
        guard readsState else { return headerState }
        guard output.summary != nil || output.errors.isEmpty else { throw SpotError.badState }
        var state = SpotState(output: output, header: headerState)
        if view != nil { state = state.holding(output.view) }
        guard isBuiltIn, let isOnGrid = output.summary?.flag("grid") else { return state }
        return state.onGrid(isOnGrid)
    }

    /// The actions that fit: those an item does not hide, and only the command's own with no item.
    public func actions(for item: SpotItem?) -> [CommandAction] {
        actions.filter { ($0.scope == .spot || item != nil) && item?.hides?.contains($0.id) != true }
    }

    /// What Enter does, in words. A slider has no Enter.
    public func openTitle(hasItem: Bool) -> String? {
        if hasItem { return openTitle ?? "Open" }
        switch kind {
        case .launch: return "Run"
        case .toggle: return "Toggle"
        case .list: return soleCommand.flatMap { command in offers.first { $0.id == command }?.title } ?? (pressRuns ? "Run" : "Open")
        case .slider: return nil
        case .widget: return opens == nil ? nil : "Open"
        }
    }
}
