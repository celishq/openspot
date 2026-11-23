import Foundation

public struct Store: Hashable, Sendable {
    public let url: URL
    public let name: String
    public let isBuiltIn: Bool

    public init(url: URL) {
        self.url = URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true)
        name = self.url.lastPathComponent
        isBuiltIn = false
    }

    private init(builtIn url: URL) {
        self.url = URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true)
        name = "Openspot"
        isBuiltIn = true
    }

    public static func builtIn(environment: [String: String]) -> Store? {
        let url = environment["OPENSPOT_EXAMPLES"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            ?? Bundle.main.resourceURL?.appendingPathComponent("examples", isDirectory: true)
        return url.map { Store(builtIn: $0) }
    }

    public static func all(builtIn: Store?, config: Config) -> [Store] {
        [builtIn].compactMap { $0 } + config.stores
    }

    var table: ConfigDocument.Table {
        ConfigDocument.Table("stores", [("path", .string(url.path))])
    }

    public func exists() -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }
}
