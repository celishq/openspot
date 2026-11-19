import Foundation

public struct NumberReading: Equatable, Sendable {
    public let text: String
    public let bare: String
    public let unit: String?
    public let points: [Double]
    public let max: Double?

    init(block: TextBlock) {
        let values = block.values("value")
        let unit = block.value("unit").flatMap { $0.isEmpty ? nil : $0 }
        let shown = block.value("display") ?? values.last ?? ""
        self.unit = unit
        bare = shown
        points = values.compactMap(Double.init).filter(\.isFinite)
        max = block.number("max")
        guard let unit, !shown.isEmpty, !shown.contains(unit) else {
            text = shown
            return
        }
        text = shown + (unit.first?.isLetter == true ? " " : "") + unit
    }

    public var isSeries: Bool {
        points.count > 1
    }

    public var fill: Double? {
        guard !isSeries, let max, max > 0, let point = points.first else { return nil }
        return Swift.min(Swift.max(point / max, 0), 1)
    }

    public var scaledPoints: [Double] {
        guard let top = max ?? points.max(), top > 0 else { return points.map { _ in 0 } }
        return points.map { Swift.min(Swift.max($0 / top, 0), 1) }
    }
}
