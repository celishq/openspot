import Foundation

/// The ID of a script in a spots folder: the name of its spot folder, then the name of the script when the two differ, such
/// as `weather` for `weather.spot/weather.sh` and `home/lights` for `home.spot/lights.sh` (protocol: A spot).
public struct SpotID: Hashable, Sendable, CustomStringConvertible {
    /// The name of its spot folder, with no extension, which its data folder and its share also take.
    public let name: String
    /// The name of its script, with no extension.
    public let script: String

    /// The ID that a text such as `home/lights` gives.
    public init(_ text: String) {
        let parts = text.split(separator: "/", maxSplits: 1).map(String.init)
        name = parts.first ?? text
        script = parts.count > 1 ? parts[1] : name
    }

    /// The ID of a script file in a spot folder.
    public init(file: URL) {
        name = file.deletingLastPathComponent().deletingPathExtension().lastPathComponent
        script = file.deletingPathExtension().lastPathComponent
    }

    /// The ID of the spot folder at the start of a path in a spots folder, such as `home.spot/lights.sh`.
    public init(path: String) {
        let first = String(path.split(separator: "/").first ?? Substring(path))
        self.init((first as NSString).deletingPathExtension)
    }

    public var description: String {
        script == name ? name : "\(name)/\(script)"
    }

    /// The name of its spot folder, such as `home.spot`.
    public var folderName: String {
        name + "." + SpotPackage.fileExtension
    }

    /// Whether another ID names a script of the same spot folder, which is one unit.
    public func isSameFolder(as other: SpotID) -> Bool {
        name == other.name
    }

    /// The place of its script with this extension in a spots folder.
    public func file(in spots: URL, extension kind: String) -> URL {
        spots.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(script).appendingPathExtension(kind)
    }

    /// Its script in a spots folder, with any extension, when one is there.
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
