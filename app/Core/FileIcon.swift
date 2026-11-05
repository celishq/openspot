import Foundation

/// Where the icon of a path comes from: the file itself, or its type, which files of that type share.
public enum FileIcon: Hashable, Sendable {
    case file(String)
    case type(String)

    private static let ownIconExtensions: Set<String> = ["app", "prefpane"]

    public init(path: String) {
        let suffix = (path as NSString).pathExtension.lowercased()
        self = suffix.isEmpty || Self.ownIconExtensions.contains(suffix) ? .file(path) : .type(suffix)
    }
}
