import Foundation

/// The last scan of the plugin folder, with the stamp of all that it read, so that a look at a folder that did not change
/// reads no file.
public struct PluginScan {
    private var result = ScanResult(plugins: [], refused: [])
    /// The stamp of all that the last scan read, which changes with each file that it reads.
    public private(set) var stamp: PluginFolder.Stamp?

    public init() {}

    /// Scans the folder when a file that the last scan read has changed, and returns the scan. A folder that cannot be read
    /// gives the sheets of the app alone.
    public mutating func look(at folder: PluginFolder, hosted: [Spot]) -> ScanResult {
        let next = folder.stamp(hosted: hosted)
        if next != stamp {
            result = (try? folder.scan(hosted: hosted)) ?? ScanResult(plugins: [Plugin(id: "openspot", commands: hosted)], refused: [])
            stamp = next
        }
        return result
    }
}
