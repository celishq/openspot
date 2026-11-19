import Foundation

public enum SpotSample {
    public static let scriptName = "sample.sh"
    public static let textName = "sample.frame"
    private static let limit: TimeInterval = 10

    public static func script(beside file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(scriptName)
    }

    public static func text(beside file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(textName)
    }

    static func isScript(_ url: URL) -> Bool {
        url.lastPathComponent == scriptName && url.deletingLastPathComponent().deletingPathExtension().lastPathComponent != "sample"
    }

    static func exists(for spot: Spot, runsScript: Bool) -> Bool {
        (runsScript && spot.sample != nil) || FileManager.default.fileExists(atPath: text(beside: spot.url).path)
    }

    @MainActor
    public static func capture(of spot: Spot, runs: SpotRuns) async throws {
        guard let sampled = spot.sampled else { throw SpotError.fault("\(spot.name) has no sample. Add \(scriptName) beside it.") }
        let text = try await runs.answer(of: sampled, .show, limit: limit)
        try text.write(to: self.text(beside: spot.url), atomically: true, encoding: .utf8)
    }

    @MainActor
    public static func output(of item: SpotCatalog.Item, runs: SpotRuns) async -> Frame? {
        if item.runsSample, let sampled = item.spot.sampled {
            guard let text = try? await runs.answer(of: sampled, .show, limit: limit) else { return nil }
            return await Frame.reading(text)
        }
        let kept = text(beside: item.spot.url)
        return await Task.detached(priority: .userInitiated) { (try? String(contentsOf: kept, encoding: .utf8)).map { Frame(text: $0) } }.value
    }
}
