import Foundation

public struct SpotInstall: Equatable, Sendable {
    public let id: String
    public let name: String
    let source: URL
    let spots: URL
    let core: URL?
    let lock: SpotLock
    let config: ConfigFile
    let trash: @Sendable (URL) throws -> Void

    public static func == (one: SpotInstall, other: SpotInstall) -> Bool {
        one.id == other.id && one.source == other.source && one.spots == other.spots && one.lock == other.lock && one.config == other.config
    }

    public func review() throws -> ReviewSpot {
        try ReviewSpot(installing: self)
    }

    public func run(isConfirmed: Bool) async throws -> String {
        let folder = source.lastPathComponent
        let asking = "Openspot installed nothing. Run `openspot store get \(id) --yes` to install it."
        _ = try await lock.add(.folder(source), to: spots, isConfirmed: isConfirmed, asking: asking, discard: trash)
        try leaveOffGrid(folder)
        return "Installed \(name).\n"
    }

    private func leaveOffGrid(_ folder: String) throws {
        let ids = ((try? SpotsFolder(url: spots).scan())?.files ?? []).flatMap(\.spots).filter { $0.url.deletingLastPathComponent().lastPathComponent == folder }.map(\.id)
        _ = try config.change { config in
            for id in ids where config.arrangement.isOnGrid(of: id) == nil { config.arrangement.set(isOnGrid: false, of: id) }
        }
    }
}
