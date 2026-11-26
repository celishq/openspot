import Foundation

public struct ReviewLine: Equatable, Sendable {
    public let title: String
    public let words: [String]

    static let filesTitle = "Files"

    public var isFiles: Bool {
        title == Self.filesTitle
    }
}
