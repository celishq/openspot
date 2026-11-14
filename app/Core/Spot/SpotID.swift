import Foundation

public struct SpotID: Hashable, Sendable, CustomStringConvertible {
    public let name: String
    public let script: String

    public init(_ text: String) {
        let parts = text.split(separator: "/", maxSplits: 1).map(String.init)
        name = parts.first ?? text
        script = parts.count > 1 ? parts[1] : name
    }

    public init(file: URL) {
        name = file.deletingLastPathComponent().deletingPathExtension().lastPathComponent
        script = file.deletingPathExtension().lastPathComponent
    }

    public init(path: String) {
        let first = String(path.split(separator: "/").first ?? Substring(path))
        self.init((first as NSString).deletingPathExtension)
    }

    public var description: String {
        script == name ? name : "\(name)/\(script)"
    }

    public var folderName: String {
        name + "." + SpotPackage.fileExtension
    }

    public func isSameFolder(as other: SpotID) -> Bool {
        name == other.name
    }

    public func file(in spots: URL, extension kind: String) -> URL {
        spots.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(script).appendingPathExtension(kind)
    }

    public func file(in spots: URL) -> URL? {
        let folder = spots.appendingPathComponent(folderName, isDirectory: true)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return nil }
        return names.sorted().lazy.map { folder.appendingPathComponent($0) }.first { file in
            var isFolder: ObjCBool = false
            return file.deletingPathExtension().lastPathComponent == script && !file.lastPathComponent.hasPrefix(".")
                && FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder) && !isFolder.boolValue
        }
    }
}
