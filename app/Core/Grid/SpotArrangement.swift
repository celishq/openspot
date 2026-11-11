import Foundation

/// What the person chose for the spots: a preferred size, whether the grid shows a spot, whether its rows join the main
/// search, whether the menu bar shows it, its letter, and the order. The grid can still change a preferred size to fill a
/// row.
public struct SpotArrangement: Equatable, Sendable {
    public struct Choice: Equatable, Sendable {
        public let id: String
        public var size: SpotSize?
        public var isOnGrid: Bool?
        public var isEnabled: Bool?
        public var isGlobal: Bool?
        public var isInMenuBar: Bool?
        /// The letter that runs the spot from the panel. An empty letter takes away the letter of the default config.
        public var letter: String?
        /// A key of the panel that opens the sheet of the spot, such as cmd+n.
        public var key: ActionKey?

        public init(id: String, size: SpotSize? = nil, isOnGrid: Bool? = nil, isEnabled: Bool? = nil, isGlobal: Bool? = nil, isInMenuBar: Bool? = nil, letter: String? = nil, key: ActionKey? = nil) {
            self.id = id
            self.size = size
            self.isOnGrid = isOnGrid
            self.isEnabled = isEnabled
            self.isGlobal = isGlobal
            self.isInMenuBar = isInMenuBar
            self.letter = letter
            self.key = key
        }
    }

    public private(set) var choices: [Choice]

    public init(choices: [Choice] = []) {
        self.choices = choices
    }

    /// The spot whose sheet a key of the panel opens: the person's choice, or else the default config's.
    public func spot(openedBy key: ActionKey, over defaults: SpotArrangement) -> String? {
        if let own = choices.first(where: { $0.key == key }) { return own.id }
        return defaults.choices.first { choice in choice.key == key && choices.first { $0.id == choice.id }?.key == nil }?.id
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

    /// The letter of each spot: each letter of these choices first, then each letter of the defaults for a spot that these
    /// choices give no letter, while no spot holds it. Of two spots with one letter, the first keeps it.
    public func letters(over defaults: SpotArrangement) -> [String: CommandKey] {
        var letters: [String: CommandKey] = [:]
        var taken = Set<String>()
        for choice in choices where letters[choice.id] == nil {
            guard let key = choice.letter.flatMap(CommandKey.init(name:)), taken.insert(key.name).inserted else { continue }
            letters[choice.id] = key
        }
        for choice in defaults.choices where letters[choice.id] == nil && self.choices.first(where: { $0.id == choice.id })?.letter == nil {
            guard let key = choice.letter.flatMap(CommandKey.init(name:)), taken.insert(key.name).inserted else { continue }
            letters[choice.id] = key
        }
        return letters
    }

    /// Gives a spot this letter, or takes its letter away with nil. Returns the spot that held the letter, which loses it.
    public mutating func give(_ letter: CommandKey?, to id: String, over defaults: SpotArrangement) -> String? {
        let holder = letter.flatMap { key in letters(over: defaults).first { $0.value == key && $0.key != id }?.key }
        if let holder { change(holder) { $0.letter = "" } }
        change(id) { $0.letter = letter?.name ?? "" }
        return holder
    }

    /// The IDs of the spots that the person put in the menu bar.
    public var menuBar: Set<String> {
        Set(choices.filter { $0.isInMenuBar == true }.map(\.id))
    }

    /// The IDs of the core spots that the person turned on.
    public var enabled: Set<String> {
        Set(choices.filter { $0.isEnabled == true }.map(\.id))
    }

    /// The IDs of the spots that the person turned off. A spot of the plugins folder loads unless it is here.
    public var disabled: Set<String> {
        Set(choices.filter { $0.isEnabled == false }.map(\.id))
    }

    /// The commands in the order of the grid: each listed one takes a place that a listed one holds, in the order of the
    /// list, and each other one stays where it is.
    public func ordered(_ spots: [Spot]) -> [Spot] {
        let places = Dictionary(choices.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
        var listed = spots.filter { places[$0.id] != nil }.sorted { places[$0.id]! < places[$1.id]! }.makeIterator()
        return spots.map { places[$0.id] != nil ? listed.next()! : $0 }
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
            if let letter = choice.letter { lines.append("letter = \"\(letter)\"") }
            if let key = choice.key { lines.append("key = \"\(key.text)\"") }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}
