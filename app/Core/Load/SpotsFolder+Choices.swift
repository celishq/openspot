import Foundation

extension SpotsFolder {
    public func scanOwnIDs() -> Set<String> {
        Set(((try? scanOwn())?.files ?? []).map(\.id))
    }

    public func scanOwn() throws -> ScanResult {
        let load = KeptScan.shared.load(SpotsFolder(url: url))
        return try load.result(enabled: load.ownIDs, disabled: [])
    }

    @discardableResult
    public func turn(_ ids: [String], on isOn: Bool, in config: ConfigFile) throws -> KeptConfig {
        let choices = Set(coreChoices().map(Self.coreID(of:)))
        let own = scanOwnIDs()
        if let id = ids.first(where: { !choices.contains($0) && !(isOn && own.contains($0)) }) {
            throw SpotError.failed(1, "`\(id)` is not a spot that comes with Openspot. Run `openspot spot list --core` to see each one.")
        }
        if !isOn, let id = ids.first(where: own.contains) {
            throw SpotError.failed(1, "`\(id)` is a file in your spots folder, so it is always on.")
        }
        return try config.change { config in ids.forEach { config.arrangement.set(isEnabled: isOn, of: $0) } }
    }
}
