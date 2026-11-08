import Foundation

/// What a menu bar item shows for a reading, or nothing before the first value or when the metric hides it.
public struct TrayMark: Equatable, Sendable {
    /// How many rows of a metric have one tone.
    public struct Count: Equatable, Sendable {
        public let tone: MetricValue.Tone?
        public let count: Int

        public init(tone: MetricValue.Tone?, count: Int) {
            self.tone = tone
            self.count = count
        }
    }

    public enum Content: Equatable, Sendable {
        case counts([Count])
        case text(String)
        case ring(fill: Double, title: String)
        case bars([Double], title: String)
        case status(String)
        /// Running work: a ring from `fill`, or a spinner with none, and how many run when there is more than one.
        case work(fill: Double?, count: Int?)
    }

    public static let barCount = 8

    public let symbol: String?
    public let tone: MetricValue.Tone?
    public let content: Content
    public let isStale: Bool
    public let summary: String

    /// What the Openspot item shows for running work, with the fill and the name of the oldest call.
    public init(workFill: Double?, count: Int, name: String) {
        symbol = nil
        tone = nil
        isStale = false
        summary = count > 1 ? "\(count) running. \(name) is the oldest" : "\(name) is running"
        content = .work(fill: workFill, count: count > 1 ? count : nil)
    }

    public init?(reading: MetricReading) {
        guard let value = reading.value, !value.isHidden else { return nil }
        symbol = reading.symbol
        tone = value.tone
        isStale = reading.isStale
        summary = "\(reading.label): \(value.title)"
        switch reading.kind {
        case .rows:
            let rows = value.rows ?? []
            let tones: [MetricValue.Tone?] = [.bad, .warn, .good, nil]
            let counts = tones.compactMap { tone -> Count? in
                let count = rows.filter { $0.tone == tone }.count
                return count > 0 ? Count(tone: tone, count: count) : nil
            }
            content = counts.isEmpty ? .text(value.title) : .counts(counts)
        case .gauge:
            content = .ring(fill: value.fill, title: value.title)
        case .trend:
            content = .bars(Array(value.scaledPoints.suffix(Self.barCount)), title: value.title)
        case .status:
            content = .status(value.title)
        case .value:
            content = .text(value.title)
        }
    }
}
