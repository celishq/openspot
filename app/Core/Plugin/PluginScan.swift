import Foundation

/// The last scan of the plugin folder, with the stamp of all that it read, so that a look at a folder that did not change
/// reads no file.
public struct PluginScan {
    private var result = ScanResult(plugins: [], refused: [])
    /// The stamp of all that the last scan read, which changes with each file that it reads.
    public private(set) var stamp: PluginFolder.Stamp?

    public init() {}

    /// Scans the folder when a file that the last scan read has changed, and returns the scan. A folder that cannot be read
    /// gives the shipped spots alone.
    public mutating func look(at folder: PluginFolder, shipped: [Spot]) -> ScanResult {
        let next = folder.stamp(shipped: shipped)
        if next != stamp {
            result = (try? folder.scan(shipped: shipped)) ?? ScanResult(plugins: [Plugin(id: "openspot", commands: shipped)], refused: [])
            stamp = next
        }
        return result
    }
}
