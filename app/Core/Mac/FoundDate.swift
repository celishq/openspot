import Foundation

public struct FoundDate: Equatable, Sendable {
    public let date: Date
    public let hasTime: Bool
    public let range: Range<String.Index>
    public let length: TimeInterval?
}
