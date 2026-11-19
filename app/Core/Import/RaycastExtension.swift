import Foundation

public struct RaycastExtension: Equatable, Sendable {
    public struct Command: Equatable, Sendable, Decodable {
        public let name: String
        public let title: String
        public let mode: String?
    }

    private struct Manifest: Decodable {
        let name: String
        let title: String?
        let description: String?
        let icon: String?
        let commands: [Command]?
    }

    public let folder: URL
    public let name: String
    public let title: String
    public let summary: String
    public let icon: URL?
    public let commands: [Command]

    public init(folder: URL) throws {
        let file = folder.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: file), let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            throw SpotError.failed(1, "\(folder.path) is not a Raycast extension: it has no package.json with a name.")
        }
        self.folder = folder
        name = manifest.name
        title = manifest.title ?? manifest.name
        summary = manifest.description ?? ""
        icon = manifest.icon.map { folder.appendingPathComponent("assets").appendingPathComponent($0) }.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        commands = manifest.commands ?? []
    }

    public static func scan(_ folder: URL) -> [RaycastExtension] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { !$0.hasPrefix(".") && $0 != "node_modules" }
            .compactMap { try? RaycastExtension(folder: folder.appendingPathComponent($0, isDirectory: true)) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public static func folder(home: URL) -> URL {
        home.appendingPathComponent(".config/raycast/extensions", isDirectory: true)
    }
}
