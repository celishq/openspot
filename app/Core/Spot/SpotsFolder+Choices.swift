import Foundation

extension SpotsFolder {
    public var ownIDs: Set<String> {
        Set(((try? SpotsFolder(url: url).keptScan())?.files ?? []).map(\.id))
    }

    public func turn(_ ids: [String], on isOn: Bool, in config: ConfigFile) throws {
        let choices = Set(keptCoreChoices().map(Self.coreID(of:)))
        let own = ownIDs
        if let id = ids.first(where: { !choices.contains($0) && !(isOn && own.contains($0)) }) {
            throw SpotError.failed(1, "`\(id)` is not a spot that comes with Openspot. Run `openspot spot list --core` to see each one.")
        }
        if !isOn, let id = ids.first(where: own.contains) {
            throw SpotError.failed(1, "`\(id)` is a file in your spots folder, so it is always on.")
        }
        var arrangement = config.read().arrangement
        ids.forEach { arrangement.set(isEnabled: isOn, of: $0) }
        try config.write(arrangement)
    }
}
