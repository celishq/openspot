import Foundation

public enum FileIcon: Hashable, Sendable {
    case file(String)
    case type(String)
    case image(String)

    private static let ownIconExtensions: Set<String> = ["app", "appex", "prefpane"]

    public init(path: String) {
        let suffix = (path as NSString).pathExtension.lowercased()
        self = suffix.isEmpty || Self.ownIconExtensions.contains(suffix) ? .file(path) : .type(suffix)
    }
}
