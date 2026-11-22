import Foundation

public struct ViewNode: Equatable, Sendable, Identifiable {
    static let parentKey = "parent"
    static let classKey = "class"

    public let id: String
    public let kind: String
    public let parent: String?
    public let block: TextBlock
    public let style: Style
    public let children: [String]
}
