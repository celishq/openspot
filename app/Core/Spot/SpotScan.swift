import Foundation

public struct SpotScan {
    private var result = ScanResult(files: [], refused: [])
    public private(set) var stamp: SpotsFolder.Stamp?

    public init() {}

    public mutating func look(at folder: SpotsFolder, hosted: [Spot]) -> ScanResult {
        let next = folder.stamp(hosted: hosted)
        if next != stamp {
            result = (try? folder.scan(hosted: hosted)) ?? ScanResult(files: [SpotFile(id: "openspot", spots: hosted)], refused: [])
            stamp = next
        }
        return result
    }
}
