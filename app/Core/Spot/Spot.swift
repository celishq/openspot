import Foundation

@dynamicMemberLookup
public struct Spot: Equatable, Sendable {
    @usableFromInline
    final class Header: Sendable {
        @usableFromInline let facts: SpotFacts
        let chipActions: [ChipAction]

        init(_ facts: SpotFacts) {
            self.facts = facts
            let actions = AttachmentValue.Kind.allCases.flatMap { kind in facts.actions.compactMap { ChipAction($0, of: facts.name, takes: kind) } }
            chipActions = actions + [ChipAction(drop: facts.triggers.drop, title: facts.name, detail: facts.subtitle)].compactMap { $0 }
        }
    }

    @usableFromInline private(set) var header: Header
    public private(set) var kind: SpotKind
    public private(set) var pick: ItemPick
    public private(set) var keepsRecent = true
    public private(set) var openTitle: String?
    public private(set) var frameActions: [CommandAction]
    public private(set) var rows: SpotRows?
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
        triggers: Manifest.Triggers = Manifest.Triggers(),
        pick: ItemPick = .close,
        isFound: Bool = true,
        order: Int = 0,
        openTitle: String? = nil,
        frameActions: [CommandAction] = [],
        host: HostSheet? = nil,
        growsFromField: Bool = false,
        mode: SpotMode = .once,
        dataName: String? = nil,
        isOnGrid: Bool = true,
        commands: [Manifest.Action] = [],
        offeredActions: [OfferedAction] = [],
        settings: [Manifest.Setting] = [],
        views: [String: String] = [:],
        viewDates: [String: Date] = [:],
        sources: [String] = [],
        pages: [String] = [],
        uses: Set<SpotUse> = [],
        keywords: [String] = [],
        sample: URL? = nil,
        editsSpots: Bool = false,
        starts: SpotStart? = nil
    ) {
        let isAttachmentSource = uses.contains(.attachment)
        header = Header(SpotFacts(
            id: id, name: name, url: url, size: size, headerIcon: icon, baseSymbol: symbol, subtitle: subtitle,
            hasSheet: triggers.shows || triggers.search == nil && commands.isEmpty && offeredActions.isEmpty,
            isFound: isFound && !isAttachmentSource, isAttachmentSource: isAttachmentSource, order: order,
            host: host, growsFromField: growsFromField, mode: mode,
            dataName: dataName, isOnGrid: isOnGrid && !isAttachmentSource, views: views, viewDates: viewDates, sources: sources, pages: pages, uses: uses,
            commands: commands, offeredActions: offeredActions, triggers: triggers, settings: settings, keywords: keywords, sample: sample,
            editsSpots: editsSpots, starts: starts
        ))
        self.kind = kind
        self.pick = pick
        self.openTitle = openTitle
        self.frameActions = frameActions
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
            && left.keepsRecent == right.keepsRecent && left.openTitle == right.openTitle
            && left.frameActions == right.frameActions && left.rows == right.rows
            && left.opensToKeys == right.opensToKeys && left.chosenIcon == right.chosenIcon
    }

    public var icon: Icon? {
        chosenIcon ?? header.facts.headerIcon
    }

    public var picture: String {
        self.image ?? self.file ?? self.glyph ?? self.symbol
    }

    public func comesBefore(_ other: Spot) -> Bool {
        self.name.localizedStandardCompare(other.name) == .orderedAscending
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

    public var reachesAccountKey: Bool {
        SpotUse.reachesAccountKey(self.uses, isBuiltIn: self.isBuiltIn)
    }

    public var fault: FaultSpot? {
        if case .fault(let fault)? = self.host { fault } else { nil }
    }

    public func action(_ id: String) throws -> Manifest.Action {
        if let action = self.actions.first(where: { $0.id == id }) { return action }
        let names = self.actions.map(\.id)
        throw SpotError.fault("\(self.name) has no action \(id). " + (names.isEmpty ? "It declares no [actions]." : "Name one of its [actions]: \(names.joined(separator: ", "))."))
    }

    public func symbol(of command: String) -> String {
        Icon(text: self.commands.first { $0.id == command }?.icon)?.symbol ?? self.symbol
    }

    public var soleCommand: String? {
        guard self.host == nil, self.commands.count == 1 else { return nil }
        return self.commands.first?.id
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

    private var settingKeys: [SpotRows.Key] {
        let icon = picture
        let commands = self.commands.map { SpotRows.Key(act: .command($0.id), title: $0.title ?? "", icon: $0.icon ?? icon) }
        return [SpotRows.Key(act: .open, title: "Open", icon: icon)] + commands + [SpotRows.Key(act: .float, title: "Float", icon: icon)]
    }

    func takingRows(isWindow: Bool = false) -> Spot {
        guard self.host == nil else { return self }
        var spot = self
        spot.rows = SpotRows(
            spot: self.id,
            fields: self.settings,
            showsInMenuBar: canShowInMenuBar,
            keys: settingKeys,
            isWindowByDefault: isWindow,
            name: self.name,
            isAttachmentSource: self.isAttachmentSource
        )
        if !self.hasSheet, !self.commands.isEmpty {
            spot.opensToKeys = true
        }
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
            triggers: self.triggers.showing,
            isFound: false,
            mode: self.mode,
            dataName: self.dataName,
            isOnGrid: false,
            uses: self.uses
        )
        spot.isBuiltIn = true
        spot.editedFile = owner.url
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

    func hidingAttachment(_ isHidden: Bool) -> Spot {
        guard isHidden, self.isAttachmentSource else { return self }
        var spot = self
        spot.isAttachmentHidden = true
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
        (self.triggers.showsOnPanel || self.showsAtLaunch) && !self.triggers.lists && !self.mode.stays
    }

    public var showsAtLaunch: Bool {
        self.triggers.events.contains(EventName.appLaunch)
    }

    var hearsEventsHidden: Bool {
        self.uses.contains(.timeline)
    }

    public var showsOfferedItems: Bool {
        self.triggers.lists && !self.triggers.showsOnPanel && self.triggers.every == nil
    }

    public var showsInSheet: Bool {
        self.triggers.opensSheet || self.showsOfferedItems
    }

    public var takesHandlers: Bool {
        self.host == nil
    }

    public var canShowInMenuBar: Bool {
        self.host == nil
    }

    public var takesFiles: Bool {
        self.triggers.drop.files
    }

    public var takesFolders: Bool {
        self.triggers.drop.takesFolders
    }

    public var takesDrops: Bool {
        self.triggers.drop.takesAny
    }

    public func runsOnOpen(over front: String?, feedsAttachment: Bool) -> Bool {
        self.triggers.opens(over: front) && (!self.isAttachmentSource || feedsAttachment && !self.isAttachmentHidden)
    }

    public func takes(_ value: AttachmentValue) -> Bool {
        self.triggers.drop.takes(value)
    }

    var chipActions: [ChipAction] {
        header.chipActions
    }

    var attachmentLook: AttachmentChip.Look? {
        fileIcon.map(AttachmentChip.Look.file) ?? (symbol.isEmpty ? nil : .symbol(symbol))
    }

    func offers(_ value: AttachmentValue) -> Bool {
        self.chipActions.contains { $0.fits(value) }
    }

    public func taking(_ output: Frame) -> Spot {
        var command = self
        command.frameActions = output.actions
        command.openTitle = output.openTitle
        command.pick = output.pick
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

    public func frameActions(for item: SpotItem?) -> [CommandAction] {
        frameActions.filter { ($0.scope == .spot || item != nil) && item?.hides?.contains($0.id) != true }
    }

    public func openTitle(hasItem: Bool) -> String? {
        if hasItem { return openTitle ?? "Open" }
        switch mainAct {
        case .toggle: return "Toggle"
        case .command(let command): return self.commands.first { $0.id == command }?.title ?? "Open"
        case .sheet: return "Open"
        case .none: return nil
        }
    }

    public func takes(route: String) -> Bool {
        self.pages.contains { fnmatch($0, route, 0) == 0 }
    }

}
