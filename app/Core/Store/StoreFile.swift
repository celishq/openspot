import Foundation

public struct StoreFile: Identifiable, Equatable, Sendable {
    public let url: URL
    public let name: String
    public let symbol: String
    public let size: String

    public var id: String {
        url.path
    }

    private static let symbols = [
        "sh": "terminal", "swift": "swift", "js": "curlybraces", "md": "doc.richtext", "toml": "gearshape", "frame": "rectangle.on.rectangle",
        "png": "photo", "jpg": "photo", "jpeg": "photo", "gif": "photo", "m": "chevron.left.forwardslash.chevron.right"
    ]

    static func read(_ paths: [String], in folder: URL) -> [StoreFile] {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return paths.map { path in
            let url = folder.appendingPathComponent(path)
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return StoreFile(
                url: url, name: path.split(separator: "/").dropFirst().joined(separator: "/"), symbol: symbols[url.pathExtension.lowercased()] ?? "doc",
                size: formatter.string(fromByteCount: Int64(bytes))
            )
        }
    }
}
