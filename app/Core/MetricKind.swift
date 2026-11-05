import Foundation

/// How a place draws a metric.
public enum MetricKind: String, CaseIterable, Sendable {
    case value
    case gauge
    case trend
    case rows
    case status
}
