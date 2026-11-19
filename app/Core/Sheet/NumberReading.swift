import Foundation

public struct NumberReading: Equatable, Sendable {
    public let text: String
    public let bare: String
    public let unit: String?
    public let points: [Double]
    public let max: Double?
    public let scaledPoints: [Double?]
    public let isSeries: Bool

    init(block: TextBlock) {
        let lines = block.values("value")
        let numbers = lines.map { Double($0).flatMap { $0.isFinite ? $0 : nil } }
        let unit = block.value("unit").flatMap { $0.isEmpty ? nil : $0 }
        let shown = block.value("display") ?? lines.last { Double($0)?.isFinite == true } ?? lines.last ?? ""
        let max = block.number("max")
        let points = numbers.compactMap { $0 }
        let top = max ?? points.max() ?? 0
        self.unit = unit
        self.points = points
        self.max = max
        bare = shown
        isSeries = lines.count > 1
        scaledPoints = numbers.map { number in number.map { top > 0 ? Swift.min(Swift.max($0 / top, 0), 1) : 0 } }
        guard let unit, !shown.isEmpty, !shown.contains(unit) else {
            text = shown
            return
        }
        text = shown + (unit.first?.isLetter == true ? " " : "") + unit
    }

    public var fill: Double? {
        guard !isSeries, let max, max > 0, let point = points.first else { return nil }
        return Swift.min(Swift.max(point / max, 0), 1)
    }

    public var level: Double? {
        guard max != nil else { return nil }
        return fill ?? scaledPoints.last ?? nil
    }
}
