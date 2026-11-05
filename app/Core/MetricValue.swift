import Foundation

/// What a metric prints when it is read.
public struct MetricValue: Equatable, Sendable {
    /// A meaning that a mark may show in colour.
    public enum Tone: String, Sendable {
        case good
        case warn
        case bad
    }

    /// One line of a metric of the rows kind.
    public struct Row: Equatable, Sendable {
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
    public let max: Double?
    public let rows: [Row]?

    public init(
        title: String,
        detail: String? = nil,
        symbol: String? = nil,
        tone: Tone? = nil,
        value: Double? = nil,
        points: [Double]? = nil,
        max: Double? = nil,
        rows: [Row]? = nil
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tone = tone
        self.value = value
        self.points = points
        self.max = max
        self.rows = rows
    }

    /// Reads the block a metric prints. Only the title is required, and a bad value is left out.
    public init?(block: TextBlock) {
        guard let title = block.value("title") else { return nil }
        let points = block.values("point").compactMap(Double.init).filter(\.isFinite)
        let rows = block.groups("row").compactMap { row in
            row.value("row").map { Row(title: $0, detail: row.value("detail"), tone: row.value("tone").flatMap(Tone.init)) }
        }
        self.init(
            title: title,
            detail: block.value("detail"),
            symbol: block.value("symbol"),
            tone: block.value("tone").flatMap(Tone.init),
            value: block.number("value"),
            points: points.isEmpty ? nil : points,
            max: block.number("max"),
            rows: rows.isEmpty ? nil : rows
        )
    }

    /// The part of a gauge that is full, from 0 to 1.
    public var fill: Double {
        Swift.min(Swift.max(value ?? 0, 0), 1)
    }

    /// The points of a trend, from 0 at zero to 1 at the top value, or at the highest point when there is none.
    public var scaledPoints: [Double] {
        let points = points ?? []
        guard let top = self.max ?? points.max(), top > 0 else { return points.map { _ in 0 } }
        return points.map { Swift.min(Swift.max($0 / top, 0), 1) }
    }
}
