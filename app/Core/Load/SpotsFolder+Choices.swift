import Foundation

extension SpotsFolder {
    public func scanOwnIDs() -> Set<String> {
        Set(((try? scanOwn())?.files ?? []).map(\.id))
    }

    public func scanOwn() throws -> ScanResult {
        try KeptScan.shared.load(SpotsFolder(url: url)).result()
    }

    @discardableResult
    public func mark(_ id: String, isNew: Bool, in config: ConfigFile) throws -> KeptConfig {
        let ids = Set(try scan().scripts.map(\.id))
        guard ids.contains(id) || !isNew else { throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.") }
        return try config.change { config in
            config.arrangement.set(isNew: isNew, of: id)
            config.arrangement.dropNew(keeping: ids.union([id]))
        }
    }
}
