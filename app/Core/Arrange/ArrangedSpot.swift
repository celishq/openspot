import Foundation

public struct ArrangedSpot: Equatable, Sendable {
    public let id: String
    public let name: String
    public let icon: String
    public let isOnGrid: Bool

    public init(id: String, name: String, icon: String, isOnGrid: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isOnGrid = isOnGrid
    }
}
