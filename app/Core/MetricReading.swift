import Foundation

/// The name, the tint and the last value of a metric. The value stays when a later read fails, and is then stale.
public struct MetricReading: Equatable, Sendable {
    public let kind: MetricKind
    public let label: String
    public let tint: MetricTint?
    public private(set) var value: MetricValue?
    public private(set) var isStale = false

    public init(kind: MetricKind, label: String, tint: MetricTint? = nil, value: MetricValue? = nil) {
        self.kind = kind
        self.label = label
        self.tint = tint
        self.value = value
    }

    public mutating func take(_ value: MetricValue) {
        self.value = value
        isStale = false
    }

    public mutating func markStale() {
        isStale = true
    }
}
