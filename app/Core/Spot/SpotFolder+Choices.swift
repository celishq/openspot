import Foundation

extension SpotFolder {
    /// The IDs of the files in the folder itself, which are always on.
    public var ownIDs: Set<String> {
        Set(((try? SpotFolder(url: url).keptScan())?.files ?? []).map(\.id))
    }

    /// Turns core spots on or off in the config, in one write. It refuses all for an ID that no core spot has, and for a
    /// file of the folder, which is always on.
    public func turn(_ ids: [String], on isOn: Bool, in config: ConfigFile) throws {
        let choices = Set(keptCoreChoices().map(Self.coreID(of:)))
        if let id = ids.first(where: { !choices.contains($0) }) {
            throw SpotError.failed(1, "`\(id)` is not a spot that comes with Openspot. Run `openspot spot list --core` to see each one.")
        }
        let own = ownIDs
        if let id = ids.first(where: own.contains) {
            throw SpotError.failed(1, "`\(id)` is a file in your spots folder, so it is always on.")
        }
        var arrangement = config.read().arrangement
        ids.forEach { arrangement.set(isEnabled: isOn, of: $0) }
        try config.write(arrangement)
    }
}
