/// The letters of an item that a search matched, as character offsets in its title and its subtitle.
/// Ranges that overlap or touch join into one.
public struct SearchMarks: Equatable, Sendable {
    public let title: [Range<Int>]
    public let subtitle: [Range<Int>]

    public init(title: [Range<Int>], subtitle: [Range<Int>]) {
        self.title = Self.joined(title)
        self.subtitle = Self.joined(subtitle)
    }

    private static func joined(_ ranges: [Range<Int>]) -> [Range<Int>] {
        ranges.sorted { $0.lowerBound < $1.lowerBound }.reduce(into: []) { result, range in
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
    }
}
