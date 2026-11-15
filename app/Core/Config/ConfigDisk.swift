import Foundation

public protocol ConfigDisk: Sendable {
    func read(_ url: URL) throws -> String?
    func write(_ text: String, to url: URL) throws
    func readStamp(of url: URL) -> String
}
