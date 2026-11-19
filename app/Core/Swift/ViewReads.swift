import Foundation

public struct ViewReads: OptionSet, Sendable {
    public let rawValue: Int

    public static let shown = ViewReads(rawValue: 1 << 0)
    public static let selection = ViewReads(rawValue: 1 << 1)

    private static let words: [(ViewReads, Data)] = [(.shown, Data("isShown".utf8)), (.selection, Data("selection".utf8))]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(source text: Data) {
        self = ViewReads(Self.words.filter { text.range(of: $0.1) != nil }.map(\.0))
    }
}
