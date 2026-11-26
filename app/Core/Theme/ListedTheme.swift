import Foundation

public struct ListedTheme: Identifiable, Equatable, Sendable {
    public let name: String
    public let isBuiltIn: Bool
    public let isUsed: Bool
    public let colours: Theme.Colours
    public let layout: Theme.Layout

    public var id: String {
        name
    }

    public var word: String {
        isUsed ? "In use" : isBuiltIn ? "Built in" : "Yours"
    }
}
