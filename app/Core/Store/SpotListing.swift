import Foundation

/// The files that a spot shows in the store beside its code: its readme, `readme.md`, and the rows that its preview mode
/// printed, `preview.txt`, at the top of its folder. A publish captures the preview, so that drawing it runs no code.
public enum SpotListing {
    public static let readmeName = "readme.md"
    public static let previewName = "preview.txt"
    /// The ends of the names of a loose file's readme and preview, which a wrap renames.
    static let readmeExtension = "md"
    static let previewSuffix = ".preview.txt"

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
