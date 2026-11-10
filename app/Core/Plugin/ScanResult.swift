public struct ScanResult: Equatable, Sendable {
    /// A file that the scan did not load, with the reason.
    public struct Refusal: Equatable, Sendable {
        public let file: String
        public let reason: String

        public init(file: String, reason: String) {
            self.file = file
            self.reason = reason
        }
    }

    public var plugins: [Plugin]
    public var refused: [Refusal]

    public init(plugins: [Plugin], refused: [Refusal]) {
        self.plugins = plugins
        self.refused = refused
    }

    /// The commands with a card, in their grid order: a lower `order` first, and otherwise as the folder sorts them.
    public var commands: [Spot] {
        plugins.flatMap(\.commands).filter(\.hasSpot).enumerated()
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
    }

    /// Each script, with a card or not. A widget is not a script.
    public var scripts: [Spot] {
        plugins.flatMap(\.commands).filter { $0.kind != .widget }
    }

    /// The assigned keys whose script still lists their command, or still offers a float (W1, T1).
    public func offered(_ keys: [GlobalKey]) -> [GlobalKey] {
        keys.filter { key in
            switch key.act {
            case .float: scripts.contains { $0.id == key.spot && $0.offersFloat }
            case .command(let command): scripts.contains { $0.id == key.spot && $0.offers.contains { $0.id == command } }
            }
        }
    }

    /// Makes each script that lists commands and has no read open to the keys of its commands.
    mutating func listKeys(with settings: SettingsSpot) {
        plugins = plugins.map { Plugin(id: $0.id, commands: $0.commands.map { $0.listingKeys(with: settings) }) }
    }

    /// Leaves out each widget that names a script with no `read` or a command no plugin has, and reports why.
    /// Takes each script that a widget opens off the grid.
    mutating func keepOpenedOffTheGrid() {
        let opened = Set(plugins.flatMap(\.commands).compactMap(\.opens))
        plugins = plugins.map { Plugin(id: $0.id, commands: $0.commands.map { opened.contains($0.id) ? $0.offTheGrid() : $0 }) }
    }

    mutating func removeWidgetsWithLostParts() {
        let metrics = Set(scripts.filter { $0.read != nil }.map(\.id))
        let commands = Set(commands.map(\.id))
        plugins = plugins.map { plugin in
            let kept = plugin.commands.filter { command in
                guard command.kind == .widget else { return true }
                var reason = command.places.first { !metrics.contains($0) }.map { "\(command.name) names no metric called \($0)" }
                if reason == nil, let opens = command.opens, !commands.contains(opens) {
                    reason = "\(command.name) opens no command called \(opens)"
                }
                if let reason { refused.append(Refusal(file: plugin.id, reason: reason)) }
                return reason == nil
            }
            return Plugin(id: plugin.id, commands: kept)
        }
    }
}
