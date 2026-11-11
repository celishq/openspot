import Foundation

/// What the person chose for the spots: a preferred size, whether the grid shows a spot, whether its rows join the main
/// search, whether the menu bar shows it, and the order. The grid can still change a preferred size to fill a row.
public struct SpotArrangement: Equatable, Sendable {
    public struct Choice: Equatable, Sendable {
        public let id: String
        public var size: SpotSize?
        public var isOnGrid: Bool?
        public var isEnabled: Bool?
        public var isGlobal: Bool?
        public var isInMenuBar: Bool?

        public init(id: String, size: SpotSize? = nil, isOnGrid: Bool? = nil, isEnabled: Bool? = nil, isGlobal: Bool? = nil, isInMenuBar: Bool? = nil) {
            self.id = id
            self.size = size
            self.isOnGrid = isOnGrid
            self.isEnabled = isEnabled
            self.isGlobal = isGlobal
            self.isInMenuBar = isInMenuBar
        }
    }

    public private(set) var choices: [Choice]

    public init(choices: [Choice] = []) {
        self.choices = choices
    }

    public func size(of id: String) -> SpotSize? {
        choices.first { $0.id == id }?.size
    }

    public func isOnGrid(of id: String) -> Bool? {
        choices.first { $0.id == id }?.isOnGrid
    }

    public func isGlobal(of id: String) -> Bool? {
        choices.first { $0.id == id }?.isGlobal
    }

    /// The IDs of the spots that the person put in the menu bar.
    public var menuBar: Set<String> {
        Set(choices.filter { $0.isInMenuBar == true }.map(\.id))
    }

    /// The IDs of the core spots that the person turned on.
    public var enabled: Set<String> {
        Set(choices.filter { $0.isEnabled == true }.map(\.id))
    }

    /// The commands in the order of the grid: each listed one takes a place that a listed one holds, in the order of the
    /// list, and each other one stays where it is.
    public func ordered(_ commands: [Spot]) -> [Spot] {
        let places = Dictionary(choices.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
        var listed = commands.filter { places[$0.id] != nil }.sorted { places[$0.id]! < places[$1.id]! }.makeIterator()
        return commands.map { places[$0.id] != nil ? listed.next()! : $0 }
    }

    /// Lists these spots in this order, with their choices. A choice for a spot that is gone stays after them.
    public mutating func arrange(_ ids: [String]) {
        let kept = choices.filter { !ids.contains($0.id) }
        choices = ids.map { id in choices.first { $0.id == id } ?? Choice(id: id) } + kept
    }

    public mutating func set(size: SpotSize, of id: String) {
        change(id) { $0.size = size }
    }

    public mutating func set(isOnGrid: Bool, of id: String) {
        change(id) { $0.isOnGrid = isOnGrid }
    }

    public mutating func set(isEnabled: Bool, of id: String) {
        change(id) { $0.isEnabled = isEnabled }
    }

    public mutating func set(isInMenuBar: Bool, of id: String) {
        change(id) { $0.isInMenuBar = isInMenuBar }
    }

    private mutating func change(_ id: String, _ work: (inout Choice) -> Void) {
        if !choices.contains(where: { $0.id == id }) { choices.append(Choice(id: id)) }
        choices.indices.filter { choices[$0].id == id }.forEach { work(&choices[$0]) }
    }

    /// The lines of its choices in the config file.
    var text: String {
        choices.map { choice in
            var lines = ["[[spots]]", "id = \"\(choice.id)\""]
            if let name = choice.size?.name { lines.append("size = \"\(name)\"") }
            if let isOnGrid = choice.isOnGrid { lines.append("grid = \(isOnGrid)") }
            if let isEnabled = choice.isEnabled { lines.append("enabled = \(isEnabled)") }
            if let isGlobal = choice.isGlobal { lines.append("global = \(isGlobal)") }
            if let isInMenuBar = choice.isInMenuBar { lines.append("tray = \(isInMenuBar)") }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}
