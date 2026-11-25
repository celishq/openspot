import Foundation

extension SpotsFolder {
    public func scanOwnIDs() -> Set<String> {
        Set(((try? scanOwn())?.files ?? []).map(\.id))
    }

    public func scanOwn() throws -> ScanResult {
        try KeptScan.shared.load(SpotsFolder(url: url)).result()
    }
}
