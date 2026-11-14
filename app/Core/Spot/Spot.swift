import Foundation

public struct Spot: Equatable, Sendable {
    private static let folderWord = "folder"
    private static let anyWord = "*"

    public let id: String
    public let name: String
    public let url: URL
    public private(set) var kind: SpotKind
    public let size: SpotSize
    public private(set) var symbol: String
    public let subtitle: String?
    public private(set) var read: SpotRead?
    public private(set) var pick: ItemPick
    public private(set) var pickForm: CommandAction?
    public let offeredPlaces: Set<Place>
    public var isGlobal: Bool { offeredPlaces.contains(.search) }
    public let isFound: Bool
    public let answers: AnswerPattern?
    public private(set) var order: Int
    public private(set) var keepsRecent = true
    public private(set) var openTitle: String?
    public private(set) var actions: [CommandAction]
    public let layout: WidgetLayout?
    public let places: [String]
    public let opens: String?
    public let host: HostSheet?
    public let growsFromField: Bool
    public let mode: SpotMode
    public let pressRuns: Bool
    public let drop: [String]
    public var offersFloat: Bool { offeredPlaces.contains(.float) }
    public var offersWindow: Bool { offeredPlaces.contains(.window) }
    public var offersCard: Bool { offeredPlaces.contains(.card) }
    public var offersMenuBar: Bool { offeredPlaces.contains(.menubar) }
    public let dataName: String?
    public private(set) var isOnGrid: Bool
    public private(set) var headerSymbol: String?
    public private(set) var file: String?
    public private(set) var image: String?
    public private(set) var glyph: String?
    public let view: String?
    public let viewDate: Date?
    public let emits: [String]
    public let pages: [String]
    public internal(set) var uses: Set<SpotUse>
    public let offers: [CommandOffer]
    public private(set) var offeredActions: [OfferedAction]
    public let settings: [CommandOffer]
    public private(set) var keyList: KeyList?
    public private(set) var listsKeysAbove = false
    public private(set) var isBuiltIn = false
    public var reachesAccountKey: Bool {
        SpotUse.reachesAccountKey(uses, isBuiltIn: isBuiltIn)
    }
    public let keywords: [String]
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
        offeredPlaces: Set<Place> = [.card, .menubar],
        dataName: String? = nil,
        isOnGrid: Bool = true,
        headerSymbol: String? = nil,
        offers: [CommandOffer] = [],
        offeredActions: [OfferedAction] = [],
        settings: [CommandOffer] = [],
        file: String? = nil,
        image: String? = nil,
        glyph: String? = nil,
        view: String? = nil,
        viewDate: Date? = nil,
        emits: [String] = [],
        pages: [String] = [],
        uses: Set<SpotUse> = [],
        keywords: [String] = [],
        previewsSample: Bool = false
    ) {
        self.emits = emits
        self.pages = pages
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
        self.offeredPlaces = offeredPlaces
        self.dataName = dataName
        self.isOnGrid = isOnGrid
        self.headerSymbol = headerSymbol
        self.offers = offers
        self.offeredActions = offeredActions
        self.settings = settings
        self.file = file
        self.image = image
        self.glyph = glyph
        self.view = view
        self.viewDate = viewDate
    }

    public var fault: FaultSpot? {
        if case .fault(let fault)? = host { fault } else { nil }
    }

    public var icon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }

    public var sizes: [SpotSize] {
        kind == .widget ? [] : SpotSize.all
    }

    public func symbol(of command: String) -> String {
        Icon(text: offers.first { $0.id == command }?.icon)?.symbol ?? symbol
    }

    public var soleCommand: String? {
        guard keyList != nil, offers.count == 1 else { return nil }
        return offers.first?.id
    }

    func listingKeys(in config: ConfigFile) -> Spot {
        guard !offers.isEmpty, host == nil else { return self }
        var spot = self
        spot.keyList = KeyList(file: config, spot: id, offers: offers, picture: image ?? file ?? glyph ?? symbol)
        guard read == nil else {
            spot.listsKeysAbove = true
            return spot
        }
        spot.kind = .list
        spot.read = .sheet
        return spot
    }

    func added(at date: Date) -> Spot {
        var spot = self
        spot.order = -Int(date.timeIntervalSince1970)
        return spot
    }

    func withIcon(_ text: String?) -> Spot {
        guard let icon = Icon(text: text) else { return self }
        var spot = self
        spot.headerSymbol = icon.symbol
        spot.symbol = icon.symbol ?? symbol
        spot.file = icon.file
        spot.image = icon.image
        spot.glyph = icon.glyph
        return spot
    }

    func builtIn() -> Spot {
        var spot = self
        spot.isBuiltIn = true
        spot.offeredActions = offeredActions.map { $0.ofTheApp() }
        return spot
    }

    func offTheGrid() -> Spot {
        var spot = self
        spot.isOnGrid = false
        return spot
    }

    public var setsKeys: Bool {
        keyList != nil
    }

    public var headerState: SpotState {
        SpotState(title: name, subtitle: subtitle, isOnGrid: isOnGrid)
    }

    public var readsState: Bool {
        (read?.has(.panel) == true || read?.has(.event(SpotEvent.appLaunch)) == true) && !isGlobal && !mode.stays
    }

    public var readsAtLaunch: Bool {
        read?.has(.event(SpotEvent.appLaunch)) == true
    }

    public var readsOfferedRows: Bool {
        guard let read else { return false }
        return isGlobal && !read.has(.panel) && read.seconds == nil
    }

    public var canShowInMenuBar: Bool {
        offersMenuBar && (read?.seconds != nil || read?.hasEvent == true || mode.stays)
    }

    public var click: SpotAction {
        .open
    }

    public var takesFiles: Bool {
        dropWords.contains { !$0.isEmpty && $0 != Self.folderWord }
    }

    public var takesFolders: Bool {
        dropWords.contains(Self.folderWord) || dropWords.contains(Self.anyWord)
    }

    public var takesDrops: Bool {
        takesFiles || takesFolders
    }

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

    public func state(of output: SpotOutput) throws -> SpotState {
        guard readsState else { return headerState }
        guard output.summary != nil || output.errors.isEmpty else { throw SpotError.badState }
        var state = SpotState(output: output, header: headerState)
        if view != nil { state = state.holding(output.view) }
        guard isBuiltIn, let isOnGrid = output.summary?.flag("grid") else { return state }
        return state.onGrid(isOnGrid)
    }

    public func actions(for item: SpotItem?) -> [CommandAction] {
        actions.filter { ($0.scope == .spot || item != nil) && item?.hides?.contains($0.id) != true }
    }

    public func openTitle(hasItem: Bool) -> String? {
        if hasItem { return openTitle ?? "Open" }
        switch kind {
        case .launch: return "Run"
        case .toggle: return "Toggle"
        case .list: return pressRuns ? "Run" : "Open"
        case .slider: return nil
        case .widget: return opens == nil ? nil : "Open"
        }
    }

    public func takes(page: String) -> Bool {
        pages.contains { fnmatch($0, page, 0) == 0 }
    }

}
