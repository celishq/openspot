import Foundation

/// What the store shows of a spot before the person turns it on: its one-line description, its readme, and the rows that its
/// preview mode printed. The readme is `<name>.md` and the preview is `<name>.preview.txt`, beside the spot's file. Drawing
/// a preview runs no code.
public struct SpotListing: Equatable, Sendable {
    public static let readmeExtension = "md"
    public static let previewSuffix = ".preview.txt"

    public let description: String?
    public let readme: String?
    public let preview: [SpotItem]

    public init(description: String?, readme: String?, preview: [SpotItem]) {
        self.description = description
        self.readme = readme
        self.preview = preview
    }

    /// The listing that the files beside this spot's file give.
    public init(beside command: Spot) {
        let readme = try? String(contentsOf: Self.readme(of: command.url), encoding: .utf8)
        let preview = (try? String(contentsOf: Self.preview(of: command.url), encoding: .utf8)).map { PluginOutput(text: $0).items } ?? []
        self.init(description: command.subtitle, readme: readme?.trimmingCharacters(in: .whitespacesAndNewlines), preview: preview)
    }

    public static func readme(of file: URL) -> URL {
        file.deletingPathExtension().appendingPathExtension(readmeExtension)
    }

    public static func preview(of file: URL) -> URL {
        let stem = file.deletingPathExtension()
        return stem.deletingLastPathComponent().appendingPathComponent(stem.lastPathComponent + previewSuffix)
    }

    /// Runs the read of a spot with `OPENSPOT_PREVIEW=1`, so that it prints fake data, and keeps the text beside its file.
    public static func capturePreview(of command: Spot) async throws {
        guard command.previewsSample else { throw PluginError.fault("\(command.name) has no preview mode. Add preview=sample to its header.") }
        var text = ""
        let process = ScriptProcess(url: command.url, arguments: ["read"], limit: 10, dataName: command.dataName, variables: ["OPENSPOT_PREVIEW": "1"])
        for try await frame in process.start() {
            text += frame
        }
        try text.write(to: preview(of: command.url), atomically: true, encoding: .utf8)
    }
}
