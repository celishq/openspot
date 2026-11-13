import Foundation

/// The last scan of the spots folder, with the stamp of all that it read, so that a look at a folder that did not change
/// reads no file.
public struct SpotScan {
    private var result = ScanResult(files: [], refused: [])
    /// The stamp of all that the last scan read, which changes with each file that it reads.
    public private(set) var stamp: SpotsFolder.Stamp?

    public init() {}

    /// Scans the folder when a file that the last scan read has changed, and returns the scan. A folder that cannot be read
    /// gives the sheets of the app alone.
    public mutating func look(at folder: SpotsFolder, hosted: [Spot]) -> ScanResult {
        let next = folder.stamp(hosted: hosted)
        if next != stamp {
            result = (try? folder.scan(hosted: hosted)) ?? ScanResult(files: [SpotFile(id: "openspot", spots: hosted)], refused: [])
            stamp = next
        }
        return result
    }
}
