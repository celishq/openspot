import Foundation

extension TextBlock {
    static let keptPoints = 60
    static let mostPoints = 600
    static let addKey = "add"

    var seriesPoints: [String] {
        let keep = number("keep").map { Int(Swift.min(Swift.max($0, 1), Double(Self.mostPoints))) } ?? Self.keptPoints
        return Array((Self.points(in: value("value")) + Self.points(in: value(Self.addKey))).suffix(keep))
    }

    func addingPoints() -> TextBlock {
        guard fields.first?.key == BlockKind.series.word, value(Self.addKey) != nil else { return self }
        let joined = Field(key: "value", value: seriesPoints.joined(separator: ","))
        var next = fields.filter { $0.key != "value" && $0.key != Self.addKey }
        next.insert(joined, at: Swift.min(1, next.count))
        return TextBlock(fields: next, firstLine: firstLine, children: children)
    }

    private static func points(in line: String?) -> [String] {
        (line ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
