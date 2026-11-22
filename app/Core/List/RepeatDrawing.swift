import Foundation

public struct RepeatDrawing: Equatable, Sendable {
    public let columns: Int

    public static let list = RepeatDrawing(columns: 1)

    public init(columns: Int) {
        self.columns = max(columns, 1)
    }
}
