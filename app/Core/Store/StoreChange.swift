import Foundation

public struct StoreChange: Equatable, Sendable {
    public let id: String
    public let name: String
    public let powers: [String]
    public let reviewed: String?
}
