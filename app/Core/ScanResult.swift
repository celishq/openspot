public struct ScanResult: Equatable, Sendable {
    public var plugins: [Plugin]
    public var refused: [Refusal]

    public init(plugins: [Plugin], refused: [Refusal]) {
        self.plugins = plugins
        self.refused = refused
    }

    /// The commands with a card, in their grid order: a lower `order` first, and otherwise as the folder sorts them.
    public var commands: [PluginCommand] {
        plugins.flatMap(\.commands).filter(\.hasSpot).sorted { $0.order < $1.order }
    }

    /// Each script, with a card or not. A widget is not a script.
    public var scripts: [PluginCommand] {
        plugins.flatMap(\.commands).filter { $0.kind != .widget }
    }

    /// The assigned keys whose script still lists their command.
    public func offered(_ keys: [GlobalKey]) -> [GlobalKey] {
        keys.filter { key in scripts.contains { $0.id == key.spot && $0.offers.contains { $0.id == key.command } } }
    }

    /// Leaves out each widget that names a script with no `read` or a command no plugin has, and reports why.
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
