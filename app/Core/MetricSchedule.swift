import Foundation

/// When each metric was last read, and so which ones are due.
public struct MetricSchedule: Sendable {
    private var lastRead: [String: Date] = [:]

    public init() {}

    /// The metrics whose refresh time has passed. Each one counts as read from now.
    public mutating func takeDue(_ metrics: [PluginMetric], now: Date) -> [PluginMetric] {
        let due = metrics.filter { metric in
            lastRead[metric.id].map { now.timeIntervalSince($0) >= metric.refresh } ?? true
        }
        due.forEach { lastRead[$0.id] = now }
        return due
    }
}
