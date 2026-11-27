import Foundation

public struct SpotChoices: Equatable, Sendable {
    public struct Choice: Equatable, Sendable {
        public let id: String
        public var size: SpotSize?
        public var isOnGrid: Bool?
        public var isFound: Bool?
        public var isGlobal: Bool?
        public var isInMenuBar: Bool?
        public var isWindow: Bool?
        public var key: ActionKey?
        public var cells: [Int: GridCell]?
        public var commands: [String: String]?
        public var isNew: Bool?

        public init(id: String, size: SpotSize? = nil, isOnGrid: Bool? = nil, isGlobal: Bool? = nil, isInMenuBar: Bool? = nil, key: ActionKey? = nil) {
            self.id = id
            self.size = size
            self.isOnGrid = isOnGrid
            self.isGlobal = isGlobal
            self.isInMenuBar = isInMenuBar
            self.key = key
        }
    }

    public private(set) var choices: [Choice] {
        didSet { places = Self.places(of: choices) }
    }
    private var places: [String: Int]

    public init(choices: [Choice] = []) {
        self.choices = choices
        places = Self.places(of: choices)
    }

    private static func places(of choices: [Choice]) -> [String: Int] {
        Dictionary(choices.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
    }

    private func choice(of id: String) -> Choice? {
        places[id].map { choices[$0] }
    }

    public func spot(openedBy key: ActionKey, over defaults: SpotChoices) -> String? {
        if let own = choices.first(where: { $0.key == key }) { return own.id }
        return defaults.choices.first { choice in choice.key == key && self.choice(of: choice.id)?.key == nil }?.id
    }

    public func size(of id: String) -> SpotSize? {
        choice(of: id)?.size
    }

    public func isOnGrid(of id: String) -> Bool? {
        choice(of: id)?.isOnGrid
    }

    public func isFound(of id: String) -> Bool? {
        choice(of: id)?.isFound
    }

    public func cells(of id: String) -> [Int: GridCell]? {
        choice(of: id)?.cells
    }

    public func isGlobal(of id: String) -> Bool? {
        choice(of: id)?.isGlobal
    }

    public func commands(of id: String) -> [String: String]? {
        choice(of: id)?.commands
    }

    public func isWindow(of id: String) -> Bool? {
        choice(of: id)?.isWindow
    }

    public var menuBar: Set<String> {
        Set(choices.filter { $0.isInMenuBar == true }.map(\.id))
    }

    public func isNew(_ id: String) -> Bool {
        choice(of: id)?.isNew == true
    }

    public var newIDs: Set<String> {
        Set(choices.filter { $0.isNew == true }.map(\.id))
    }

    public func names(_ id: String) -> Bool {
        places[id] != nil
    }

    public func ordered(_ spots: [Spot]) -> [Spot] {
        var listed = spots.filter { places[$0.id] != nil }.sorted { places[$0.id]! < places[$1.id]! }.makeIterator()
        return spots.map { places[$0.id] != nil ? listed.next()! : $0 }
    }

    public mutating func arrange(_ ids: [String]) {
        let listed = Set(ids)
        let kept = choices.filter { !listed.contains($0.id) }
        choices = ids.map { id in choice(of: id) ?? Choice(id: id) } + kept
    }

    public mutating func set(size: SpotSize, of id: String) {
        change(id) { $0.size = size }
    }

    public mutating func set(isOnGrid: Bool, of id: String) {
        change(id) { $0.isOnGrid = isOnGrid }
    }

    public mutating func set(cell: GridCell?, of id: String, columns: Int) {
        change(id) { choice in
            var cells = choice.cells ?? [:]
            cells[columns] = cell
            choice.cells = cells.isEmpty ? nil : cells
        }
    }

    public mutating func set(isInMenuBar: Bool, of id: String) {
        change(id) { $0.isInMenuBar = isInMenuBar }
    }

    public mutating func set(isWindow: Bool, of id: String) {
        change(id) { $0.isWindow = isWindow }
    }

    public mutating func set(isNew: Bool, of id: String) {
        guard isNew || places[id] != nil else { return }
        change(id) { $0.isNew = isNew ? true : nil }
        choices.removeAll { $0.id == id && $0 == Choice(id: id) }
    }

    public mutating func dropNew(keeping ids: Set<String>) {
        for choice in choices where choice.isNew == true && !ids.contains(choice.id) { set(isNew: false, of: choice.id) }
    }

    private mutating func change(_ id: String, _ work: (inout Choice) -> Void) {
        if places[id] == nil { choices.append(Choice(id: id)) }
        choices.indices.filter { choices[$0].id == id }.forEach { work(&choices[$0]) }
    }

    var tables: [ConfigDocument.Table] {
        choices.map { choice in
            ConfigDocument.Table("spots", [
                ("id", .string(choice.id)),
                ("size", (choice.size?.name).map { .string($0) }),
                ("grid", choice.isOnGrid.map { .boolean($0) }),
                ("search", choice.isFound.map { .boolean($0) }),
                ("global", choice.isGlobal.map { .boolean($0) }),
                ("tray", choice.isInMenuBar.map { .boolean($0) }),
                ("window", choice.isWindow.map { .boolean($0) }),
                ("key", (choice.key?.text).map { .string($0) }),
                ("places", choice.cells.map { cells in .table(Dictionary(uniqueKeysWithValues: cells.map { (String($0.key), .string("\($0.value.row) \($0.value.column)")) })) }),
                ("commands", choice.commands.map { .table($0.mapValues { .string($0) }) }),
                ("new", choice.isNew.map { .boolean($0) })
            ])
        }
    }
}
