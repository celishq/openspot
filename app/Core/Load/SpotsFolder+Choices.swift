import Foundation

extension SpotsFolder {
    public func scanOwnIDs() -> Set<String> {
        Set(((try? scanOwn())?.files ?? []).map(\.id))
    }

    public func scanOwn() throws -> ScanResult {
        try KeptScan.shared.load(SpotsFolder(url: url)).result()
    }

    @discardableResult
    public func mark(_ id: String, as mark: SpotMark?, in config: ConfigFile) throws -> KeptConfig {
        let ids = Set(try scan().scripts.map(\.id))
        guard ids.contains(id) || mark != .new else { throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.") }
        return try config.change { config in
            config.arrangement.set(mark: mark, of: id)
            config.arrangement.dropMarks(keeping: ids.union([id]))
        }
    }
}
