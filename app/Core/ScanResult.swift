public struct ScanResult: Equatable, Sendable {
    public var plugins: [Plugin]
    public var refused: [Refusal]

    public init(plugins: [Plugin], refused: [Refusal]) {
        self.plugins = plugins
        self.refused = refused
    }

    public var commands: [PluginCommand] {
        plugins.flatMap(\.commands)
    }

    public var metrics: [PluginMetric] {
        plugins.flatMap(\.metrics)
    }

    /// Leaves out each widget that names a metric or a command no plugin has, and reports why.
    mutating func removeWidgetsWithLostParts() {
        let metrics = Set(metrics.map(\.id))
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
            return Plugin(id: plugin.id, commands: kept, metrics: plugin.metrics)
        }
    }
}
