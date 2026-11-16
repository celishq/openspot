import Foundation

public struct SpotArrangement: Equatable, Sendable {
    public struct Choice: Equatable, Sendable {
        public let id: String
        public var size: SpotSize?
        public var isOnGrid: Bool?
        public var isEnabled: Bool?
        public var isGlobal: Bool?
        public var isInMenuBar: Bool?
        public var key: ActionKey?
        public var panel: GridPanel?

        public init(id: String, size: SpotSize? = nil, isOnGrid: Bool? = nil, isEnabled: Bool? = nil, isGlobal: Bool? = nil, isInMenuBar: Bool? = nil, key: ActionKey? = nil) {
            self.id = id
            self.size = size
            self.isOnGrid = isOnGrid
            self.isEnabled = isEnabled
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

    public func spot(openedBy key: ActionKey, over defaults: SpotArrangement) -> String? {
        if let own = choices.first(where: { $0.key == key }) { return own.id }
        return defaults.choices.first { choice in choice.key == key && self.choice(of: choice.id)?.key == nil }?.id
    }

    public func size(of id: String) -> SpotSize? {
        choice(of: id)?.size
    }

    public func isOnGrid(of id: String) -> Bool? {
        choice(of: id)?.isOnGrid
    }

    public func panel(of id: String) -> GridPanel? {
        choice(of: id)?.panel
    }

    public func isGlobal(of id: String) -> Bool? {
        choice(of: id)?.isGlobal
    }

    public var menuBar: Set<String> {
        Set(choices.filter { $0.isInMenuBar == true }.map(\.id))
    }

    public var enabled: Set<String> {
        Set(choices.filter { $0.isEnabled == true }.map(\.id))
    }

    public var disabled: Set<String> {
        Set(choices.filter { $0.isEnabled == false }.map(\.id))
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

    public mutating func set(panel: GridPanel, of id: String) {
        change(id) { $0.panel = panel == .center ? nil : panel }
    }

    public mutating func set(isEnabled: Bool, of id: String) {
        change(id) { $0.isEnabled = isEnabled }
    }

    public mutating func set(isInMenuBar: Bool, of id: String) {
        change(id) { $0.isInMenuBar = isInMenuBar }
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
                ("enabled", choice.isEnabled.map { .boolean($0) }),
                ("global", choice.isGlobal.map { .boolean($0) }),
                ("tray", choice.isInMenuBar.map { .boolean($0) }),
                ("key", (choice.key?.text).map { .string($0) }),
                ("side", (choice.panel?.rawValue).map { .string($0) })
            ])
        }
    }
}
