import Foundation

public struct Plugin: Equatable, Sendable {
    public let name: String
    public let api: Int
    public let url: URL

    public init(name: String, api: Int, url: URL) {
        self.name = name
        self.api = api
        self.url = url
    }
}
