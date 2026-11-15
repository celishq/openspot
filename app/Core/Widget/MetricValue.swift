import Foundation

public struct MetricValue: Equatable, Sendable {
    public enum Tone: String, Sendable {
        case good
        case warn
        case bad
    }

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
        self.isHidden = isHidden
    }

    public init?(output: SpotOutput) {
        let rows = output.rows.compactMap { block in
            block.value("row").map { Row(title: block.value("title") ?? $0, detail: block.value("detail"), tone: block.value("tone").flatMap(Tone.init)) }
        }
        guard let block = output.metric else {
            guard output.errors.isEmpty || !rows.isEmpty else { return nil }
            self.init(title: rows.isEmpty ? "–" : String(rows.count), rows: rows.isEmpty ? nil : rows, isHidden: rows.isEmpty)
            return
        }
        let isNumber = block.fields.first?.key == "number"
        guard let title = (isNumber ? block.value("value") : block.value("title")) ?? (rows.isEmpty ? nil : String(rows.count)) else { return nil }
        let data = Self.data(of: block)
        self.init(
            title: title,
            detail: isNumber ? block.value("title") : block.value("detail"),
            symbol: Icon(text: block.value("icon"))?.symbol,
            tone: block.value("tone").flatMap(Tone.init),
            value: data.value,
            points: data.points,
            max: block.number("max"),
            rows: rows.isEmpty ? nil : rows
        )
    }

    static func data(of block: TextBlock) -> (value: Double?, points: [Double]?) {
        let kind = block.fields.first?.key
        if kind == "number" { return (nil, nil) }
        if kind == "graph" || (kind == "text" && block.value("max") != nil) {
            let points = block.values("value").compactMap(Double.init).filter(\.isFinite)
            return (nil, points.isEmpty ? nil : points)
        }
        return (block.number("value"), nil)
    }

    public var kind: MetricKind {
        if rows != nil { return .rows }
        if value != nil { return .gauge }
        if points != nil { return .trend }
        return tone != nil && symbol == nil ? .status : .value
    }

    public var fill: Double {
        Swift.min(Swift.max(value ?? 0, 0), 1)
    }

    public var scaledPoints: [Double] {
        let points = points ?? []
        guard let top = self.max ?? points.max(), top > 0 else { return points.map { _ in 0 } }
        return points.map { Swift.min(Swift.max($0 / top, 0), 1) }
    }
}
