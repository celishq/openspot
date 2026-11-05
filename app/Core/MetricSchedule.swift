import Foundation

/// When each metric was last read, and so which ones are due.
public struct MetricSchedule: Sendable {
    private var lastRead: [String: Date] = [:]

    public init() {}

    /// The metrics to keep fresh: those in the menu bar always, and those that a widget places while the panel is open.
    public static func wanted(_ metrics: [PluginMetric], by commands: [PluginCommand], isPanelOpen: Bool) -> [PluginMetric] {
        let ids = isPanelOpen ? Set(commands.flatMap(\.places)) : Set(commands.compactMap(\.tray))
        return metrics.filter { ids.contains($0.id) }
    }

    /// The metrics whose refresh time has passed. Each one counts as read from now.
    public mutating func takeDue(_ metrics: [PluginMetric], now: Date) -> [PluginMetric] {
        let due = metrics.filter { metric in
            lastRead[metric.id].map { now.timeIntervalSince($0) >= metric.refresh } ?? true
        }
        due.forEach { lastRead[$0.id] = now }
        return due
    }
}
