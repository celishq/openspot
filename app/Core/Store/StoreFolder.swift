import Foundation

public struct StoreFolder: Hashable, Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true)
    }

    public var name: String {
        url.lastPathComponent
    }

    var table: ConfigDocument.Table {
        ConfigDocument.Table("stores", [("path", .string(url.path))])
    }

    public func exists() -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }
}
