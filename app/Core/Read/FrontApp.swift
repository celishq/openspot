import Foundation

public struct FrontApp: Equatable, Sendable {
    public let bundleID: String
    public let path: String?
    public let name: String

    public init(bundleID: String, path: String? = nil, name: String? = nil) {
        self.bundleID = bundleID
        self.path = path
        self.name = name ?? path.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension } ?? bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }
}
