import Foundation

public struct SpotInstall: Equatable, Sendable {
    public let id: String
    public let name: String
    let source: URL
    let origin: SpotSource
    let expecting: SpotPackage?
    let reviewed: String?
    let spots: URL
    let core: URL?
    let lock: SpotLock
    let config: ConfigFile
    let trash: @Sendable (URL) throws -> Void

    public static func == (one: SpotInstall, other: SpotInstall) -> Bool {
        one.id == other.id && one.source == other.source && one.origin == other.origin && one.expecting == other.expecting && one.reviewed == other.reviewed && one.spots == other.spots && one.lock == other.lock && one.config == other.config
    }

    public func review() throws -> ReviewSpot {
        try ReviewSpot(installing: self)
    }

    public func clashes() -> Bool {
        FileManager.default.fileExists(atPath: spots.appendingPathComponent(target).path)
    }

    public func run(_ clash: SpotClash? = nil, isConfirmed: Bool) async throws -> String {
        let command = "openspot store get \(id)"
        let clash = clashes() ? clash : nil
        if clashes(), clash == nil {
            throw SpotError.failed(1, "Your spots have \(id) already. Run `\(command) --replace` to move yours to the Trash, or `\(command) --keep-both` to install this one as \(SpotID(path: free()).name).")
        }
        let folder = clash == .keepBoth ? free() : target
        let asking = "Openspot installed nothing. Run `\(command)\(clash.map { " --\($0.rawValue)" } ?? "") --yes` to install it."
        _ = try await lock.add(
            origin, to: spots, isConfirmed: isConfirmed, replaces: clash == .replace ? [folder] : [], expecting: expecting, reviewed: reviewed, naming: folder,
            asking: asking, discard: trash
        )
        try leaveOffGrid(folder)
        return clash == .keepBoth ? "Installed \(name) as \(SpotID(path: folder).name).\n" : "Installed \(name).\n"
    }

    private var target: String {
        SpotID(path: source.lastPathComponent).folderName
    }

    private func free() -> String {
        let base = SpotID(path: target).name
        let taken = { (name: String) in ([spots] + (core.map { [$0] } ?? [])).contains { FileManager.default.fileExists(atPath: $0.appendingPathComponent(name).path) } }
        return (2...).lazy.map { SpotID("\(base)-\($0)").folderName }.first { !taken($0) } ?? base
    }

    private func leaveOffGrid(_ folder: String) throws {
        let ids = ((try? SpotsFolder(url: spots).scan())?.files ?? []).flatMap(\.spots).filter { $0.url.deletingLastPathComponent().lastPathComponent == folder }.map(\.id)
        _ = try config.change { config in
            for id in ids where config.arrangement.isOnGrid(of: id) == nil { config.arrangement.set(isOnGrid: false, of: id) }
        }
    }
}
