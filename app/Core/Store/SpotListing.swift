import Foundation

public enum SpotListing {
    public static let readmeName = "readme.md"
    public static let sampleScriptName = "sample.sh"
    public static let sampleName = "sample.txt"
    public static let olderSampleName = "preview.txt"
    static let readmeExtension = "md"
    static let olderSampleSuffix = ".preview.txt"
    private static let sampleLimit: TimeInterval = 10

    public static func readme(of file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(readmeName)
    }

    public static func sampleScript(of file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(sampleScriptName)
    }

    public static func sampleText(of file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(sampleName)
    }

    static func isSampleScript(_ url: URL) -> Bool {
        url.lastPathComponent == sampleScriptName && url.deletingLastPathComponent().deletingPathExtension().lastPathComponent != "sample"
    }

    @MainActor
    public static func captureSample(of spot: Spot, runs: SpotRuns) async throws {
        guard let sampled = spot.sampled else { throw SpotError.fault("\(spot.name) has no sample. Add \(sampleScriptName) beside it.") }
        let text = try await runs.answer(of: sampled, .read, limit: sampleLimit)
        try text.write(to: sampleText(of: spot.url), atomically: true, encoding: .utf8)
    }

    @MainActor
    public static func sample(of spot: Spot, runsScript: Bool, runs: SpotRuns) async -> String? {
        if runsScript, let sampled = spot.sampled {
            return try? await runs.answer(of: sampled, .read, limit: sampleLimit)
        }
        let folder = spot.url.deletingLastPathComponent()
        return await Task.detached(priority: .userInitiated) {
            [sampleName, olderSampleName].lazy.compactMap { try? String(contentsOf: folder.appendingPathComponent($0), encoding: .utf8) }.first
        }.value
    }

    static func hasKeptSample(beside file: URL) -> Bool {
        [sampleName, olderSampleName].contains { FileManager.default.fileExists(atPath: file.deletingLastPathComponent().appendingPathComponent($0).path) }
    }
}
