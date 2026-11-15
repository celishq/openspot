import Foundation

public protocol ConfigDisk: Sendable {
    func read(_ url: URL) -> String?
    func write(_ text: String, to url: URL) throws
    func readStamp(of url: URL) -> String
}
