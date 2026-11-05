import Foundation

/// What a metric prints when it is read.
public struct MetricValue: Decodable, Equatable, Sendable {
    /// A meaning that a mark may show in colour.
    public enum Tone: String, Decodable, Sendable {
        case good
        case warn
        case bad
    }

    /// One line of a metric of the rows kind.
    public struct Row: Decodable, Equatable, Sendable {
        public let title: String
        public let detail: String?
        public let tone: Tone?

        public init(title: String, detail: String? = nil, tone: Tone? = nil) {
            self.title = title
            self.detail = detail
            self.tone = tone
        }
    }

    public let title: String
    public let detail: String?
    public let symbol: String?
    public let tone: Tone?
    public let value: Double?
    public let points: [Double]?
    public let rows: [Row]?

    public init(
        title: String,
        detail: String? = nil,
        symbol: String? = nil,
        tone: Tone? = nil,
        value: Double? = nil,
        points: [Double]? = nil,
        rows: [Row]? = nil
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tone = tone
        self.value = value
        self.points = points
        self.rows = rows
    }

    /// The part of a gauge that is full, from 0 to 1.
    public var fill: Double {
        min(max(value ?? 0, 0), 1)
    }

    /// The points of a trend, from 0 at the lowest to 1 at the highest. Equal points lie in the middle.
    public var scaledPoints: [Double] {
        let points = points ?? []
        guard let low = points.min(), let high = points.max() else { return [] }
        return points.map { high > low ? ($0 - low) / (high - low) : 0.5 }
    }
}
