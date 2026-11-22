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
    public private(set) var opensToKeys = false
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
        on: ShowEvents? = nil,
        pick: ItemPick = .close,
        isFound: Bool = true,
        answers: AnswerPattern? = nil,
        order: Int = 0,
        openTitle: String? = nil,
        actions: [CommandAction] = [],
        host: HostSheet? = nil,
        growsFromField: Bool = false,
        mode: SpotMode = .once,
        drop: [String] = [],
        isGlobal: Bool = false,
        dataName: String? = nil,
        isOnGrid: Bool = true,
        offers: [Manifest.Command] = [],
        offeredActions: [OfferedAction] = [],
        settings: [Manifest.Setting] = [],
        views: [String: String] = [:],
        viewDates: [String: Date] = [:],
        sources: [String] = [],
        emits: [String] = [],
        pages: [String] = [],
        uses: Set<SpotUse> = [],
        keywords: [String] = [],
        placeholder: String? = nil,
        sample: URL? = nil,
        edits: SpotEdits? = nil,
        starts: SpotStart? = nil
    ) {
        header = Header(SpotFacts(
            id: id, name: name, url: url, size: size, headerIcon: icon, baseSymbol: symbol, subtitle: subtitle, on: on,
            hasSheet: on != nil || answers == nil && offers.isEmpty && offeredActions.isEmpty,
            isGlobal: isGlobal, isFound: isFound, answers: answers, order: order,
            host: host, growsFromField: growsFromField, mode: mode, drop: drop,
            dataName: dataName, isOnGrid: isOnGrid, views: views, viewDates: viewDates, sources: sources, emits: emits, pages: pages, uses: uses,
            offers: offers, offeredActions: offeredActions, settings: settings, keywords: keywords, placeholder: placeholder, sample: sample,
            edits: edits, starts: starts
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
            && left.opensToKeys == right.opensToKeys && left.chosenIcon == right.chosenIcon
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

    public var on: ShowEvents? {
        header.facts.on
    }

    public var reachesAccountKey: Bool {
        SpotUse.reachesAccountKey(self.uses, isBuiltIn: self.isBuiltIn)
    }

    public var fault: FaultSpot? {
        if case .fault(let fault)? = self.host { fault } else { nil }
    }

    public func symbol(of command: String) -> String {
        Icon(text: self.offers.first { $0.id == command }?.icon)?.symbol ?? self.symbol
    }

    public var soleCommand: String? {
        guard self.host == nil, self.offers.count == 1 else { return nil }
        return self.offers.first?.id
    }

    public var mainAct: MainAct {
        switch kind {
        case .toggle: .toggle
        case .slider: MainAct.none
        case .launch, .list: soleCommand.map(MainAct.command) ?? .sheet
        }
    }

    public var opensOnReturn: Bool {
        mainAct == .sheet
    }

    public var keepsHistory: Bool {
        soleCommand != nil && self.hasSheet
    }

    private var settingKeys: [SpotSettings.Key] {
        let icon = self.image ?? self.file ?? self.glyph ?? self.symbol
        let commands = self.offers.map { SpotSettings.Key(act: .command($0.id), title: $0.title, icon: $0.icon ?? icon) }
        return [SpotSettings.Key(act: .open, title: "Open", icon: icon)] + commands + [SpotSettings.Key(act: .float, title: "Float", icon: icon)]
    }

    func takingSettings(in config: ConfigFile, secrets: SecretStore, isWindow: Bool = false) -> Spot {
        guard self.host == nil else { return self }
        var spot = self
        spot.settingsSheet = SpotSettings(
            file: config,
            secrets: secrets,
            spot: self.id,
            fields: self.settings,
            showsInMenuBar: canShowInMenuBar,
            keys: settingKeys,
            isWindowByDefault: isWindow
        )
        if !self.hasSheet, !self.offers.isEmpty {
            spot.opensToKeys = true
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
            on: .sheet,
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
            on: self.on,
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
        spot.sources = []
        return spot
    }

    public var headerState: SpotState {
        SpotState(title: self.name, subtitle: self.subtitle, isOnGrid: self.isOnGrid)
    }

    public var showsState: Bool {
        (self.on?.has(.panel) == true || self.on?.has(.event(SpotEvent.appLaunch)) == true) && !self.isGlobal && !self.mode.stays
    }

    public var showsAtLaunch: Bool {
        self.on?.has(.event(SpotEvent.appLaunch)) == true
    }

    public var showsOfferedItems: Bool {
        guard let on = self.on else { return false }
        return self.isGlobal && !on.has(.panel) && on.seconds == nil
    }

    public var canShowInMenuBar: Bool {
        self.host == nil
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

    public func taking(_ output: Frame) -> Spot {
        var command = self
        command.actions = output.actions
        command.openTitle = output.openTitle
        command.pick = output.pick
        command.pickForm = output.pickForm
        command.keepsRecent = output.keepsRecent
        if showsState { command.kind = output.kind }
        return command
    }

    public func state(of output: Frame) throws -> SpotState {
        guard showsState else { return headerState }
        guard output.root != nil || output.errors.isEmpty else { throw SpotError.badState }
        var state = SpotState(output: output, header: headerState).leading(with: icon ?? .symbol(symbol))
        guard self.isBuiltIn, let isOnGrid = output.root?.flag(RootKey.shown) else { return state }
        return state.onGrid(isOnGrid)
    }

    public func actions(for item: SpotItem?) -> [CommandAction] {
        actions.filter { ($0.scope == .spot || item != nil) && item?.hides?.contains($0.id) != true }
    }

    public func openTitle(hasItem: Bool) -> String? {
        if hasItem { return openTitle ?? "Open" }
        switch mainAct {
        case .toggle: return "Toggle"
        case .command(let command): return self.offers.first { $0.id == command }?.title ?? "Open"
        case .sheet: return "Open"
        case .none: return nil
        }
    }

    public func takes(route: String) -> Bool {
        self.pages.contains { fnmatch($0, route, 0) == 0 }
    }

}
