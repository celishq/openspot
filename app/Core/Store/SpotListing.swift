import Foundation

/// What the store shows of a spot before the person turns it on: its one-line description, its readme, and the rows that its
/// preview mode printed. The readme is `readme.md` and the preview is `preview.txt`, at the top of the spot's folder. Drawing
/// a preview runs no code.
public struct SpotListing: Equatable, Sendable {
    public static let readmeName = "readme.md"
    public static let previewName = "preview.txt"
    /// The ends of the names of a loose file's readme and preview, which a wrap renames.
    static let readmeExtension = "md"
    static let previewSuffix = ".preview.txt"

    public let description: String?
    public let readme: String?
    public let preview: [SpotItem]

    public init(description: String?, readme: String?, preview: [SpotItem]) {
        self.description = description
        self.readme = readme
        self.preview = preview
    }

    /// The listing that the files beside this spot's file give.
    public init(beside spot: Spot) {
        let readme = try? String(contentsOf: Self.readme(of: spot.url), encoding: .utf8)
        let preview = (try? String(contentsOf: Self.preview(of: spot.url), encoding: .utf8)).map { SpotOutput(text: $0).items } ?? []
        self.init(description: spot.subtitle, readme: readme?.trimmingCharacters(in: .whitespacesAndNewlines), preview: preview)
    }

    public static func readme(of file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(readmeName)
    }

    public static func preview(of file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(previewName)
    }

    /// Runs the read of a spot through these runs with `OPENSPOT_REASON=spot.preview`, so that it prints fake data as the spot's own
    /// call, and keeps the text beside its file.
    @MainActor
    public static func capturePreview(of spot: Spot, runs: SpotRuns) async throws {
        guard spot.previewsSample else { throw SpotError.fault("\(spot.name) has no preview mode. Add preview=sample to its header.") }
        let text = try await runs.answer(of: spot, .read, limit: 10, variables: ReadReason.preview.variables)
        try text.write(to: preview(of: spot.url), atomically: true, encoding: .utf8)
    }
}
