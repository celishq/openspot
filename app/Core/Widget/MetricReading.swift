import Foundation

/// The name and the last value of a metric. The value stays when a later read fails, and is then stale.
public struct MetricReading: Equatable, Sendable {
    public private(set) var kind: MetricKind
    public let label: String
    public let headerSymbol: String?
    public private(set) var value: MetricValue?
    public private(set) var isStale = false

    public init(label: String, headerSymbol: String? = nil, value: MetricValue? = nil) {
        kind = value?.kind ?? .value
        self.label = label
        self.headerSymbol = headerSymbol
        self.value = value
    }

    public var symbol: String? {
        value?.symbol ?? headerSymbol
    }

    public var tint: MetricTint? {
        value?.tint
    }

    /// Takes a new value. When a metric has nothing to show it keeps its kind, and rows then count zero.
    public mutating func take(_ value: MetricValue) {
        isStale = false
        if value.isHidden {
            self.value = kind == .rows ? MetricValue(title: "0", isHidden: true) : value
        } else {
            kind = value.kind
            self.value = value
        }
    }

    public mutating func markStale() {
        isStale = true
    }
}
