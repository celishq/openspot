import Foundation

/// Where a picture comes from: the icon of a file, the icon of a type, which files of that type share, or an image.
public enum FileIcon: Hashable, Sendable {
    case file(String)
    case type(String)
    case image(String)

    private static let ownIconExtensions: Set<String> = ["app", "prefpane"]

    public init(path: String) {
        let suffix = (path as NSString).pathExtension.lowercased()
        self = suffix.isEmpty || Self.ownIconExtensions.contains(suffix) ? .file(path) : .type(suffix)
    }
}
