import Foundation

public enum SpotListing {
    public static let readmeName = "readme.md"
    public static let previewName = "preview.txt"
    static let readmeExtension = "md"
    static let previewSuffix = ".preview.txt"

    public static func readme(of file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(readmeName)
    }

    public static func preview(of file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(previewName)
    }

    @MainActor
    public static func capturePreview(of spot: Spot, runs: SpotRuns) async throws {
        guard spot.previewsSample else { throw SpotError.fault("\(spot.name) has no preview mode. Add preview=sample to its header.") }
        let text = try await runs.answer(of: spot, .read, limit: 10, variables: ReadReason.preview.variables)
        try text.write(to: preview(of: spot.url), atomically: true, encoding: .utf8)
    }
}
