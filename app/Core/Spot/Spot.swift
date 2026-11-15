import Foundation

@dynamicMemberLookup
public struct Spot: Equatable, Sendable {
    @usableFromInline
    final class Header: Sendable {
        @usableFromInline let facts: SpotFacts

        init(_ facts: SpotFacts) {
            self.facts = facts
        }
    }

    private static let folderWord = "folder"
    private static let anyWord = "*"

    @usableFromInline private(set) var header: Header
    public private(set) var kind: SpotKind
    public private(set) var pick: ItemPick
    public private(set) var pickForm: CommandAction?
    public private(set) var keepsRecent = true
    public private(set) var openTitle: String?
    public private(set) var actions: [CommandAction]
    public private(set) var settingsSheet: SpotSettings?
    public private(set) var opensToSettings = false
    private var chosenIcon: Icon?

    public init(
        id: String,
        name: String,
        url: URL,
        kind: SpotKind = .launch,
        size: SpotSize = .wide,
        symbol: String = "app",
        icon: Icon? = nil,
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
        offers: [CommandOffer] = [],
        offeredActions: [OfferedAction] = [],
        settings: [CommandOffer] = [],
        view: String? = nil,
        viewDate: Date? = nil,
        sources: [String] = [],
        emits: [String] = [],
        pages: [String] = [],
        uses: Set<SpotUse> = [],
        keywords: [String] = [],
        sample: URL? = nil,
        editsSpots: Bool = false
    ) {
        header = Header(SpotFacts(
            id: id, name: name, url: url, size: size, headerIcon: icon, baseSymbol: symbol, subtitle: subtitle, read: read,
            offeredPlaces: offeredPlaces, isFound: isFound, answers: answers, order: order, layout: layout, places: places,
            opens: opens, host: host, growsFromField: growsFromField, mode: mode, pressRuns: pressRuns, drop: drop,
            dataName: dataName, isOnGrid: isOnGrid, view: view, viewDate: viewDate, sources: sources, emits: emits, pages: pages, uses: uses,
            offers: offers, offeredActions: offeredActions, settings: settings, keywords: keywords, sample: sample,
            editsSpots: editsSpots
        ))
        self.kind = kind
        self.pick = pick
        self.openTitle = openTitle
        self.actions = actions
    }

    @inlinable
    public subscript<Value>(dynamicMember path: KeyPath<SpotFacts, Value>) -> Value {
        header.facts[keyPath: path]
    }

    public subscript<Value>(dynamicMember path: WritableKeyPath<SpotFacts, Value>) -> Value {
        get { header.facts[keyPath: path] }
        set {
            var facts = header.facts
            facts[keyPath: path] = newValue
            header = Header(facts)
        }
    }

    public static func == (left: Spot, right: Spot) -> Bool {
        (left.header === right.header || left.header.facts == right.header.facts) && left.kind == right.kind && left.pick == right.pick
            && left.pickForm == right.pickForm && left.keepsRecent == right.keepsRecent && left.openTitle == right.openTitle
            && left.actions == right.actions && left.settingsSheet == right.settingsSheet
            && left.opensToSettings == right.opensToSettings && left.chosenIcon == right.chosenIcon
    }

    public var icon: Icon? {
        chosenIcon ?? header.facts.headerIcon
    }

    public var symbol: String {
        icon?.symbol ?? header.facts.baseSymbol
    }

    public var headerSymbol: String? {
        icon?.symbol
    }

    public var image: String? {
        icon?.image
    }

    public var file: String? {
        icon?.file
    }

    public var glyph: String? {
        icon?.glyph
    }

    public var fileIcon: FileIcon? {
        image.map(FileIcon.image) ?? file.map(FileIcon.init(path:))
    }

    public var read: SpotRead? {
        header.facts.read
    }

    public var isGlobal: Bool { self.offeredPlaces.contains(.search) }
    public var offersFloat: Bool { self.offeredPlaces.contains(.float) }
    public var offersWindow: Bool { self.offeredPlaces.contains(.window) }
    public var offersCard: Bool { self.offeredPlaces.contains(.card) }
    public var offersMenuBar: Bool { self.offeredPlaces.contains(.menubar) }
    public var reachesAccountKey: Bool {
        SpotUse.reachesAccountKey(self.uses, isBuiltIn: self.isBuiltIn)
    }

    public var fault: FaultSpot? {
        if case .fault(let fault)? = self.host { fault } else { nil }
    }

    public var sizes: [SpotSize] {
        kind == .widget ? [] : SpotSize.all
    }

    public func symbol(of command: String) -> String {
        Icon(text: self.offers.first { $0.id == command }?.icon)?.symbol ?? self.symbol
    }

    public var soleCommand: String? {
        guard self.host == nil, self.offers.count == 1 else { return nil }
        return self.offers.first?.id
    }

    public var opensOnReturn: Bool {
        kind.opensSheet && !self.pressRuns && soleCommand == nil
    }

    public var keepsHistory: Bool {
        soleCommand != nil && !self.opensToSettings && self.read != nil
    }

    func takingSettings(in config: ConfigFile, secrets: SecretStore) -> Spot {
        guard self.host == nil else { return self }
        var spot = self
        spot.settingsSheet = SpotSettings(
            file: config,
            secrets: secrets,
            spot: self.id,
            offers: self.offers,
            fields: self.settings,
            offersFloat: offersFloat,
            showsInMenuBar: canShowInMenuBar
        )
        if self.read == nil, !self.offers.isEmpty {
            spot.kind = .list
            spot.opensToSettings = true
        }
        return spot
    }

    public var settingsSpot: Spot? {
        guard let settingsSheet = self.settingsSheet, !self.holdsSettings else { return nil }
        var spot = Spot(
            id: SpotSettings.sheetID(of: self.id),
            name: "\(self.name) Settings",
            url: self.url,
            kind: .list,
            size: self.size,
            symbol: header.facts.baseSymbol,
            icon: self.icon,
            read: .sheet,
            isFound: false,
            isOnGrid: false
        )
        spot.settingsSheet = self.settingsSheet
        spot.holdsSettings = true
        return spot
    }

    public func editSheet(of owner: Spot, isOwn: Bool) -> Spot? {
        guard self.editsSpots, self.isBuiltIn else { return nil }
        var spot = Spot(
            id: OwnedSheet.edit.id(of: owner.id),
            name: "Edit \(owner.name)",
            url: self.url,
            kind: .list,
            size: owner.size,
            symbol: owner.header.facts.baseSymbol,
            icon: owner.icon,
            read: self.read,
            isFound: false,
            mode: self.mode,
            dataName: self.dataName,
            isOnGrid: false,
            uses: self.uses
        )
        spot.isBuiltIn = true
        spot.editedFile = isOwn ? owner.url : nil
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
        spot.chosenIcon = icon
        return spot
    }

    func builtIn() -> Spot {
        var spot = self
        spot.isBuiltIn = true
        spot.offeredActions = self.offeredActions.map { $0.ofTheApp() }
        return spot
    }

    public var sampled: Spot? {
        guard let sample = self.sample else { return nil }
        var spot = self
        spot.url = sample
        spot.mode = .once
        return spot
    }

    func offTheGrid() -> Spot {
        var spot = self
        spot.isOnGrid = false
        return spot
    }

    public var headerState: SpotState {
        SpotState(title: self.name, subtitle: self.subtitle, isOnGrid: self.isOnGrid)
    }

    public var readsState: Bool {
        (self.read?.has(.panel) == true || self.read?.has(.event(SpotEvent.appLaunch)) == true) && !isGlobal && !self.mode.stays
    }

    public var readsAtLaunch: Bool {
        self.read?.has(.event(SpotEvent.appLaunch)) == true
    }

    public var readsOfferedRows: Bool {
        guard let read = self.read else { return false }
        return isGlobal && !read.has(.panel) && read.seconds == nil
    }

    public var canShowInMenuBar: Bool {
        self.host == nil
    }

    public var showsValueInMenuBar: Bool {
        offersMenuBar && (self.read?.seconds != nil || self.read?.hasEvent == true || self.mode.stays)
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
        accepts(FileKinds.Disk().read(paths))
    }

    public func accepts(_ files: FileKinds) -> Bool {
        !files.paths.isEmpty && files.paths.allSatisfy { accepts(path: $0, kind: files.kind(of: $0)) }
    }

    private func accepts(path: String, kind: FileKinds.Kind?) -> Bool {
        guard let kind else { return false }
        if kind == .folder { return takesFolders }
        let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        if dropWords.contains(Self.anyWord) { return true }
        return !fileExtension.isEmpty && fileExtension != Self.folderWord && dropWords.contains(fileExtension)
    }

    private var dropWords: [String] {
        self.drop.map { $0.lowercased() }
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
        if self.view != nil { state = state.holding(output.view) }
        guard self.isBuiltIn, let isOnGrid = output.summary?.flag(HeadKey.shown) else { return state }
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
        case .list: return soleCommand.flatMap { command in self.offers.first { $0.id == command }?.title } ?? (self.pressRuns ? "Run" : "Open")
        case .slider: return nil
        case .widget: return self.opens == nil ? nil : "Open"
        }
    }

    public func takes(page: String) -> Bool {
        self.pages.contains { fnmatch($0, page, 0) == 0 }
    }

}
