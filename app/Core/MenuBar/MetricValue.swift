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
    public let number: NumberReading?
    public let rows: [Row]?
    public let isHidden: Bool

    public init(
        title: String,
        detail: String? = nil,
        symbol: String? = nil,
        tone: Tone? = nil,
        number: NumberReading? = nil,
        rows: [Row]? = nil,
        isHidden: Bool = false
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tone = tone
        self.number = number
        self.rows = rows
        self.isHidden = isHidden
    }

    public init?(output: Frame) {
        let main = output.metric?.fields.first?.value
        let rows = output.items.filter { $0.run != main }.map { Row(title: $0.title, detail: $0.subtitle, tone: $0.tone) }
        guard let block = output.metric else {
            guard output.errors.isEmpty || !rows.isEmpty else { return nil }
            self.init(title: rows.isEmpty ? "–" : String(rows.count), rows: rows.isEmpty ? nil : rows, isHidden: rows.isEmpty)
            return
        }
        let number = output.valueKind == .number || output.valueKind == .series ? NumberReading(block: block) : nil
        let shown = number?.text ?? block.value("title")
        guard let title = shown.flatMap({ $0.isEmpty ? nil : $0 }) ?? (rows.isEmpty ? nil : String(rows.count)) else { return nil }
        self.init(
            title: title,
            detail: number == nil ? block.value("detail") : block.value("title"),
            symbol: Icon(text: block.value("icon"))?.symbol,
            tone: block.value("tone").flatMap(Tone.init),
            number: number,
            rows: rows.isEmpty ? nil : rows
        )
    }

    public var kind: MetricKind {
        if rows != nil { return .rows }
        if number?.look != .stat, number?.fill != nil { return .gauge }
        if number?.isSeries == true { return .trend }
        return tone != nil && symbol == nil ? .status : .value
    }
}
