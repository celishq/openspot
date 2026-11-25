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

    public static func exists(for spot: Spot, runsScript: Bool) -> Bool {
        (runsScript && spot.sample != nil) || FileManager.default.fileExists(atPath: text(beside: spot.url).path)
    }

    @MainActor
    public static func output(of item: SpotCatalog.Item, runs: SpotRuns) async -> Frame? {
        await output(of: item.spot, runsScript: item.runsSample, runs: runs)
    }

    @MainActor
    public static func output(of spot: Spot, runsScript: Bool, runs: SpotRuns) async -> Frame? {
        if runsScript, let sampled = spot.sampled {
            guard let text = try? await runs.answer(of: sampled, ScriptEntry.show.name, limit: limit) else { return nil }
            return await Frame.reading(text, kinds: sampled.kinds)
        }
        let kept = text(beside: spot.url)
        let kinds = spot.kinds
        return await Task.detached(priority: .userInitiated) { (try? String(contentsOf: kept, encoding: .utf8)).map { Frame(text: $0, kinds: kinds) } }.value
    }
}
