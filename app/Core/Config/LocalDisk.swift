import Foundation

public struct LocalDisk: ConfigDisk {
    public init() {}

    public func read(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    public func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public func readStamp(of url: URL) -> String {
        guard let values = try? FileManager.default.attributesOfItem(atPath: url.path) else { return "" }
        let date = (values[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(values[.systemFileNumber] ?? 0) \(date) \(values[.size] ?? 0)"
    }
}
