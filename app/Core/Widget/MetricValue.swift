import Foundation

/// What a metric prints when it is read.
public struct MetricValue: Equatable, Sendable {
    /// A meaning that a mark may show in colour.
    public enum Tone: String, Sendable {
        case good
        case warn
        case bad
        /// A plain dot that says that a thing is active.
        case on
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
    public let tint: MetricTint?
    public let isHidden: Bool

    public init(
        title: String,
        detail: String? = nil,
        symbol: String? = nil,
        tone: Tone? = nil,
        value: Double? = nil,
        points: [Double]? = nil,
        max: Double? = nil,
        rows: [Row]? = nil,
        tint: MetricTint? = nil,
        isHidden: Bool = false
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tone = tone
        self.value = value
        self.points = points
        self.max = max
        self.rows = rows
        self.tint = tint
        self.isHidden = isHidden
    }

    /// Reads what a metric prints: its first `text`, `gauge` or `graph` (H1), or its rows. Nothing means nothing to show. Rows
    /// count themselves, and all else needs a title.
    public init?(output: PluginOutput) {
        let rows = output.rows.compactMap { block in
            block.value("row").map { Row(title: block.value("title") ?? $0, detail: block.value("detail"), tone: block.value("tone").flatMap(Tone.init)) }
        }
        guard let block = output.metric else {
            guard output.errors.isEmpty || !rows.isEmpty else { return nil }
            self.init(title: rows.isEmpty ? "–" : String(rows.count), rows: rows.isEmpty ? nil : rows, isHidden: rows.isEmpty)
            return
        }
        guard let title = block.value("title") ?? (rows.isEmpty ? nil : String(rows.count)) else { return nil }
        let points = block.values("point").compactMap(Double.init).filter(\.isFinite)
        self.init(
            title: title,
            detail: block.value("detail"),
            symbol: block.value("symbol"),
            tone: block.value("tone").flatMap(Tone.init),
            value: block.number("value"),
            points: points.isEmpty ? nil : points,
            max: block.number("max"),
            rows: rows.isEmpty ? nil : rows,
            tint: block.value("tint").flatMap(MetricTint.init)
        )
    }

    /// How a place draws this value, which follows from what the script printed.
    public var kind: MetricKind {
        if rows != nil { return .rows }
        if value != nil { return .gauge }
        if points != nil { return .trend }
        return tone != nil && symbol == nil ? .status : .value
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
