import Foundation

public protocol MacClipboard: Sendable {
    func copy(text: String) throws
    func copy(file: URL) throws
    func text() -> String
    func types() -> Set<String>
    func files() -> [URL]
    func count() -> Int
    func image() -> Data?
    func paste() throws
}
