import Foundation

public struct FrontApp: Equatable, Sendable {
    public let bundleID: String
    public let path: String?

    public init(bundleID: String, path: String? = nil) {
        self.bundleID = bundleID
        self.path = path
    }
}
