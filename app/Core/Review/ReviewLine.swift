import Foundation

public struct ReviewLine: Equatable, Sendable {
    public let title: String
    public let words: [String]

    static let filesTitle = "Files"
    static let usesTitle = "Uses"

    public var isFiles: Bool {
        title == Self.filesTitle
    }

    public var isUses: Bool {
        title == Self.usesTitle
    }
}
